import 'auth.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const CuscoLimpioApp()); }
const _green = Color(0xFF176B52);
const _dark = Color(0xFF103D32);
const _background = Color(0xFFF5F8F4);
const _center = LatLng(-13.525, -71.962);

// Fotografías reales se guardan como archivo local y las muestras usan assets.
Widget reportPhoto(String source, {double height=100, double? width, BoxFit fit=BoxFit.cover}) {
  if (source.startsWith('data:')) {
    try {return Image.memory(base64Decode(source.substring(5)),height:height,width:width,fit:fit);} catch (_) {return const Icon(Icons.broken_image_outlined);}
  }
  if (source.startsWith('file:') && !kIsWeb) {
    return Image.file(File(source.substring(5)), height:height, width:width, fit:fit,
      errorBuilder:(_,__,___)=>const Center(child:Icon(Icons.broken_image_outlined)));
  }
  return Image.asset('assets/images/$source.jpg',height:height,width:width,fit:fit);
}

class CleanReport {
  final String id, district, address, description, type, photo;
  final String createdBy;
  String status, priority, collector;
  final double lat, lng;
  final DateTime createdAt;
  CleanReport({required this.id, required this.district, required this.address,
    required this.description, required this.type, required this.photo,
    required this.status, required this.priority, required this.collector,
    required this.lat, required this.lng, this.createdBy='demo', DateTime? createdAt}):createdAt=createdAt??DateTime(2026,10,20);
  LatLng get location => LatLng(lat,lng);
  Map<String,dynamic> toJson() => {'id':id,'district':district,'address':address,
    'description':description,'type':type,'photo':photo,'createdBy':createdBy,'status':status,
    'priority':priority,'collector':collector,'lat':lat,'lng':lng,'createdAt':createdAt.toIso8601String()};
  factory CleanReport.fromJson(Map<String,dynamic> m) => CleanReport(
    id:m['id'] as String,district:m['district'] as String,address:m['address'] as String,
    description:m['description'] as String,type:m['type'] as String,photo:m['photo'] as String,createdBy:(m['createdBy']??'demo').toString(),
    status:m['status'] as String,priority:m['priority'] as String,
    collector:m['collector'] as String,lat:(m['lat'] as num).toDouble(),lng:(m['lng'] as num).toDouble(),createdAt:DateTime.tryParse((m['createdAt']??'').toString())??DateTime(2026,10,20));
}

List<CleanReport> demoReports() => [
  CleanReport(createdAt:DateTime(2026,10,12,9,25),id:'CUS-00254', district:'Wanchaq', address:'Av. La Cultura', description:'Bolsas de residuos acumuladas junto a la vereda.',type:'Domésticos',photo:'domesticos',status:'Solucionado',priority:'Alta',collector:'Brigada 01',lat:-13.5218,lng:-71.9564),
  CleanReport(createdAt:DateTime(2026,10,13,15),id:'CUS-00255', district:'Wanchaq', address:'Cerca del mercado Wanchaq',description:'Botellas y envolturas cerca de la zona comercial.',type:'Plásticos',photo:'plasticos',status:'En atención',priority:'Media',collector:'Brigada 02',lat:-13.529,lng:-71.959),
  CleanReport(createdAt:DateTime(2026,10,15,10),id:'CUS-00256', district:'San Sebastián',address:'Plaza de San Sebastián',description:'Escombros sobre la vía pública.',type:'Escombros',photo:'escombros',status:'Pendiente',priority:'Alta',collector:'Sin asignar',lat:-13.5305,lng:-71.9362),
  CleanReport(createdAt:DateTime(2026,10,17,8),id:'CUS-00257', district:'Cusco',address:'Av. El Sol',description:'Restos de alimentos cerca de contenedores.',type:'Orgánicos',photo:'domesticos',status:'En verificación',priority:'Baja',collector:'Brigada 03',lat:-13.5238,lng:-71.9752),
  CleanReport(createdAt:DateTime(2026,10,19,12),id:'CUS-00258',district:'San Jerónimo',address:'Avenida principal de San Jerónimo',description:'Residuos dispersos al costado de la avenida.',type:'Domésticos',photo:'domesticos',status:'Pendiente',priority:'Media',collector:'Sin asignar',lat:-13.5473,lng:-71.8861),
  CleanReport(createdAt:DateTime(2026,10,21,17),id:'CUS-00259',district:'Santiago',address:'Zona urbana de Santiago',description:'Botellas plásticas en la vía.',type:'Plásticos',photo:'plasticos',status:'En atención',priority:'Media',collector:'Brigada 03',lat:-13.5339,lng:-71.9874),
  CleanReport(createdAt:DateTime(2026,10,24,11),id:'CUS-00260',district:'Cusco',address:'Centro Histórico de Cusco',description:'Acumulación de residuos domésticos.',type:'Domésticos',photo:'domesticos',status:'Pendiente',priority:'Alta',collector:'Brigada 01',lat:-13.5163,lng:-71.9781),
];

class DataStore extends ChangeNotifier {
  List<CleanReport> reports=demoReports();
  final Set<String> collected={};
  final List<String> audit=[];
  final Map<String,String> notes={};
  bool loaded=false;
  Future<void> load() async {
    try {
      final p=await SharedPreferences.getInstance();
      final raw=p.getString('cusco_limpio_reports_v1');
      if(raw!=null) reports=(jsonDecode(raw) as List).map((e)=>CleanReport.fromJson(Map<String,dynamic>.from(e as Map))).toList();
      collected.addAll(p.getStringList('cusco_limpio_collected_v1')??[]);
      audit.addAll(p.getStringList('cusco_limpio_audit_v3')??[]);
      final savedNotes=p.getString('cusco_limpio_notes_v3');
      if(savedNotes!=null) notes.addAll(Map<String,String>.from(jsonDecode(savedNotes) as Map));
    } catch (_) { /* Demo remains usable if local storage is unavailable. */ }
    loaded=true;notifyListeners();
  }
  Future<void> save() async {
    notifyListeners();
    final p=await SharedPreferences.getInstance();
    await p.setString('cusco_limpio_reports_v1',jsonEncode(reports.map((e)=>e.toJson()).toList()));
    await p.setStringList('cusco_limpio_collected_v1',collected.toList());
    await p.setStringList('cusco_limpio_audit_v3',audit.take(200).toList());
    await p.setString('cusco_limpio_notes_v3',jsonEncode(notes));
  }
  void record(String actor,String action){audit.insert(0,'${dateLabel(DateTime.now())} ${DateTime.now().hour.toString().padLeft(2,'0')}:${DateTime.now().minute.toString().padLeft(2,'0')} · $actor · $action');}
  Future<void> add(CleanReport r) async {reports.insert(0,r);record(r.createdBy,'Registró reporte ${r.id}');await save();}
  Future<void> status(CleanReport r,String s) async {r.status=s;record('Municipalidad','Estado ${r.id}: $s');await save();}
  Future<void> assign(CleanReport r,String who) async {r.collector=who;record('Municipalidad','Asignó ${r.id} a $who');await save();}
  Future<void> setPriority(CleanReport r,String priority) async {r.priority=priority;record('Municipalidad','Prioridad ${r.id}: $priority');await save();}
  Future<void> addNote(CleanReport r,String note) async {notes[r.id]=note;record('Municipalidad','Observación registrada en ${r.id}');await save();}
  Future<void> toggleCollected(String id) async {
    if(!collected.add(id)) collected.remove(id);
    record('Recolector','Cambió atención de $id');await save();
  }
  Future<void> reset() async {reports=demoReports();collected.clear();audit.clear();notes.clear();await save();}
}

class CuscoLimpioApp extends StatefulWidget {
  const CuscoLimpioApp({super.key});
  @override State<CuscoLimpioApp> createState()=>_CuscoLimpioAppState();
}
class _CuscoLimpioAppState extends State<CuscoLimpioApp> {
  final store=DataStore();
  final auth=DemoAuth();
  @override void initState(){super.initState();store.load();auth.initialize();}
  @override void dispose(){store.dispose();auth.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>MaterialApp(
    title:'Cusco Limpio',debugShowCheckedModeBanner:false,
    theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:_green),scaffoldBackgroundColor:const Color(0xFFF3F8F5),
      appBarTheme:const AppBarTheme(backgroundColor:_background,foregroundColor:_dark,centerTitle:false),
      cardTheme:CardThemeData(color:Colors.white,elevation:1,shadowColor:const Color(0x170E7059),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22),side:const BorderSide(color:Color(0xFFE1EAE3))))),
    home:AnimatedBuilder(animation:auth,builder:(context,_) {
      if(!auth.ready)return const Scaffold(body:Center(child:CircularProgressIndicator()));
      return auth.current==null?EntryPage(auth:auth):AppShell(key:ValueKey(auth.current!.id),store:store,auth:auth);
    }));
}

enum UserRole {citizen,municipal,collector,admin}
String roleName(UserRole role)=>switch(role){UserRole.citizen=>'Ciudadano',UserRole.municipal=>'Municipalidad',UserRole.collector=>'Recolector',UserRole.admin=>'Administrador'};

class AppShell extends StatefulWidget {
  final DataStore store;
  final DemoAuth auth;
  const AppShell({super.key,required this.store,required this.auth});
  @override State<AppShell> createState()=>_AppShellState();
}
class _AppShellState extends State<AppShell> {
  int tab=0;
  @override Widget build(BuildContext context){
    final user=widget.auth.current!;
    final role= user.role=='admin'?UserRole.admin:user.role=='collector'?UserRole.collector:user.role=='citizen'?UserRole.citizen:UserRole.municipal;
    final labels=role==UserRole.citizen?['Inicio','Mapa','Mis reportes','Rutas','Mi cuenta']:role==UserRole.collector?['Mi jornada','Mapa','Asignados','Rutas','Mis puntos']:role==UserRole.admin?['Panel','Mapa','Auditoría','Rutas','Usuarios']:['Operaciones','Mapa','Bandeja','Rutas','Gestión'];
    final icons=[Icons.home_outlined,Icons.map_outlined,Icons.report_outlined,Icons.alt_route,role==UserRole.collector?Icons.route:role==UserRole.citizen?Icons.person_outline:role==UserRole.admin?Icons.admin_panel_settings_outlined:Icons.settings_outlined];
    final screens=<Widget>[
      role==UserRole.admin?AdminHome(store:widget.store,onNavigate:(i)=>setState(()=>tab=i)):HomeView(store:widget.store,role:role,userId:user.id,onNavigate:(i)=>setState(()=>tab=i)),
      ReportsMapView(store:widget.store),
      role==UserRole.admin?AuditView(store:widget.store):ReportsView(store:widget.store,role:role,userId:user.id,brigade:user.brigade),
      RoutesView(store:widget.store),
      role==UserRole.collector?CollectorView(store:widget.store,brigade:user.brigade):
        role==UserRole.citizen?AccountView(user:user,auth:widget.auth,store:widget.store):role==UserRole.admin?AdminDashboard(store:widget.store,auth:widget.auth):ManagementView(store:widget.store,role:role),
    ];
    return Scaffold(
      appBar:AppBar(title:const Row(mainAxisSize:MainAxisSize.min,children:[CircleAvatar(radius:17,backgroundColor:Color(0xFFE0F4E8),child:Icon(Icons.eco,color:_green,size:20)),SizedBox(width:9),Text('Cusco Limpio',style:TextStyle(fontWeight:FontWeight.w900))]),
        actions:[PopupMenuButton<String>(tooltip:'Sesión y cuenta',
          onSelected:(option){if(option=='logout')widget.auth.signOut();else setState(()=>tab=4);},
          itemBuilder:(_)=>[PopupMenuItem(value:'profile',child:Text(user.name)),const PopupMenuItem(value:'logout',child:Row(children:[Icon(Icons.logout),SizedBox(width:9),Text('Cerrar sesión')]))],
          child:Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:Chip(avatar:const Icon(Icons.verified_user_outlined,size:17),label:Text(user.role=='admin'?'Administrador':roleName(role)))))]),
      body:SafeArea(child:AnimatedBuilder(animation:widget.store,builder:(_,__)=>IndexedStack(index:tab,children:screens))),
      bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:[
        for(int i=0;i<5;i++)NavigationDestination(icon:Icon(icons[i]),label:labels[i]),
      ]),
    );
  }
}


// Panel exclusivo de Administrador: supervisión y control global.
// No asigna ni resuelve reportes; esa operación corresponde a Municipalidad.
class AdminHome extends StatelessWidget {
  final DataStore store;
  final ValueChanged<int> onNavigate;
  const AdminHome({super.key,required this.store,required this.onNavigate});
  @override Widget build(BuildContext context) {
    final active=store.reports.where((r)=>r.status!='Solucionado').length;
    final unassigned=store.reports.where((r)=>r.collector=='Sin asignar' && r.status!='Solucionado').length;
    return ListView(padding:const EdgeInsets.all(16),children:[
      Container(padding:const EdgeInsets.all(23),decoration:BoxDecoration(borderRadius:BorderRadius.circular(24),gradient:const LinearGradient(colors:[Color(0xFF172A46),Color(0xFF375D89)])),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.admin_panel_settings,color:Colors.white,size:42),const SizedBox(height:13),const Text('Centro de supervisión',style:TextStyle(fontSize:27,fontWeight:FontWeight.w800,color:Colors.white)),const SizedBox(height:7),const Text('Administrador · Vista general y seguimiento del sistema',style:TextStyle(color:Colors.white70)),const SizedBox(height:13),FilledButton.icon(onPressed:()=>onNavigate(4),icon:const Icon(Icons.insights),label:const Text('Abrir panel administrativo'))])),
      const SizedBox(height:14),Row(children:[Expanded(child:_Metric(label:'Total de reportes',value:'${store.reports.length}',icon:Icons.inventory_2_outlined)),const SizedBox(width:8),Expanded(child:_Metric(label:'En seguimiento',value:'$active',icon:Icons.query_stats)),const SizedBox(width:8),Expanded(child:_Metric(label:'Sin asignar',value:'$unassigned',icon:Icons.warning_amber_outlined))]),
      const SizedBox(height:18),const Text('Supervisión del sistema',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800)),
      _InfoTile(icon:Icons.admin_panel_settings_outlined,title:'Indicadores y brigadas',subtitle:'Revisa el estado de las operaciones y la distribución de reportes.',onTap:()=>onNavigate(4)),
      _InfoTile(icon:Icons.fact_check_outlined,title:'Auditar incidencias',subtitle:'Consulta reportes de todos los distritos sin cambiar asignaciones.',onTap:()=>onNavigate(2)),
      _InfoTile(icon:Icons.map_outlined,title:'Cobertura territorial',subtitle:'Inspecciona la distribución geográfica de los reportes.',onTap:()=>onNavigate(1)),
    ]);
  }
}

class AdminDashboard extends StatelessWidget {
  final DataStore store;
  final DemoAuth auth;
  const AdminDashboard({super.key,required this.store,required this.auth});
  @override Widget build(BuildContext context) {
    final statuses=['Pendiente','En verificación','En atención','Solucionado'];
    final brigades=['Brigada 01','Brigada 02','Brigada 03'];
    final completed=store.reports.where((r)=>r.status=='Solucionado').length;
    final percent=store.reports.isEmpty?0:(100*completed/store.reports.length).round();
    return ListView(padding:const EdgeInsets.all(16),children:[
      Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(borderRadius:BorderRadius.circular(20),color:const Color(0xFFE9EFF8)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Panel de administración',style:TextStyle(fontSize:23,fontWeight:FontWeight.w900,color:Color(0xFF172A46))),SizedBox(height:7),Text('Supervisión general · Indicadores · Control de cobertura',style:TextStyle(color:Color(0xFF3E5878)))])),
      const SizedBox(height:14),Row(children:[Expanded(child:_Metric(label:'Incidencias',value:'${store.reports.length}',icon:Icons.analytics_outlined)),const SizedBox(width:10),Expanded(child:_Metric(label:'Resueltas',value:'$percent%',icon:Icons.task_alt))]),
      const SizedBox(height:15),const Text('Estado de los reportes',style:TextStyle(fontWeight:FontWeight.w800,fontSize:18)),
      for(final status in statuses)Card(child:ListTile(leading:Icon(status=='Solucionado'?Icons.check_circle_outline:Icons.radio_button_unchecked,color:const Color(0xFF375D89)),title:Text(status),trailing:Text('${store.reports.where((r)=>r.status==status).length}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:19)))),
      const SizedBox(height:12),const Text('Cobertura por brigada',style:TextStyle(fontWeight:FontWeight.w800,fontSize:18)),
      for(final brigade in brigades)Card(child:ListTile(leading:const Icon(Icons.local_shipping_outlined,color:Color(0xFF375D89)),title:Text(brigade),subtitle:const Text('Incidencias vinculadas'),trailing:Text('${store.reports.where((r)=>r.collector==brigade).length}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:19)))),
      const SizedBox(height:14),Card(color:const Color(0xFFF2F5F9),child:const Padding(padding:EdgeInsets.all(15),child:Text('La administración consulta resultados y supervisa el sistema. Para asignar brigadas o cambiar estados debes ingresar al perfil Municipalidad. Las estadísticas corresponden a los datos almacenados en este dispositivo.'))),
      const SizedBox(height:14),FilledButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>UserManagementView(auth:auth,store:store))),icon:const Icon(Icons.manage_accounts),label:const Text('Administrar usuarios y permisos')),
      const SizedBox(height:14),OutlinedButton.icon(onPressed:auth.signOut,icon:const Icon(Icons.logout),label:const Text('Cerrar sesión')),
    ]);
  }
}

class AccountView extends StatelessWidget {
  final DemoUser user;
  final DemoAuth auth;
  final DataStore store;
  const AccountView({super.key,required this.user,required this.auth,required this.store});
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(18),children:[
    const CircleAvatar(radius:40,child:Icon(Icons.person,size:42)),const SizedBox(height:14),
    Text(user.name,textAlign:TextAlign.center,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800)),
    Text(user.email,textAlign:TextAlign.center,style:const TextStyle(color:Colors.black54)),
    const SizedBox(height:17),Card(child:ListTile(leading:const Icon(Icons.badge_outlined),title:const Text('Perfil'),subtitle:const Text('Ciudadano'))),
    Card(child:ListTile(leading:const Icon(Icons.assignment_outlined),title:const Text('Reportes en este teléfono'),subtitle:Text('${store.reports.length} reportes disponibles en este dispositivo'))),
    Card(child:ListTile(leading:const Icon(Icons.lock_outline),title:const Text('Privacidad y almacenamiento'),subtitle:const Text('Sesión local, sin cuentas remotas ni sincronización. No ingreses datos sensibles.'))),
    const SizedBox(height:17),OutlinedButton.icon(onPressed:auth.signOut,icon:const Icon(Icons.logout),label:const Text('Cerrar sesión')),
  ]);
}

class HomeView extends StatelessWidget {
  final DataStore store; final UserRole role; final String userId; final ValueChanged<int> onNavigate;
  const HomeView({super.key,required this.store,required this.role,required this.userId,required this.onNavigate});
  @override Widget build(BuildContext context){
    final pending=store.reports.where((r)=>r.status!='Solucionado').length;
    return ListView(padding:const EdgeInsets.all(16),children:[
      Container(padding:const EdgeInsets.all(23),decoration:BoxDecoration(gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF082E30),Color(0xFF167B64),Color(0xFF36A979)]),borderRadius:BorderRadius.circular(24)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.eco_outlined,color:Colors.white,size:40),const SizedBox(height:12),
          Text(role==UserRole.municipal?'Centro de operaciones':role==UserRole.collector?'Mi jornada de recolección':'Cusco más limpio, juntos',style:const TextStyle(fontSize:26,fontWeight:FontWeight.w800,color:Colors.white)),
          const SizedBox(height:8),Text('${roleName(role)} · Gestión ambiental',style:const TextStyle(color:Colors.white70)),
          const SizedBox(height:15),FilledButton.icon(onPressed:()=>onNavigate(role==UserRole.collector?4:1),icon:const Icon(Icons.map),label:Text(role==UserRole.collector?'Ver puntos asignados':'Explorar mapa'))])),
      const SizedBox(height:15),Row(children:[Expanded(child:_Metric(label:'Reportes',value:'${store.reports.length}',icon:Icons.assignment_outlined)),const SizedBox(width:9),Expanded(child:_Metric(label:'Por atender',value:'$pending',icon:Icons.pending_actions_outlined)),const SizedBox(width:9),Expanded(child:_Metric(label:'Atendidos',value:'${store.collected.length}',icon:Icons.check_circle_outline))]),
      const SizedBox(height:12),_HistorySummary(store:store),
      const SizedBox(height:20),const Text('Accesos rápidos',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800)),const SizedBox(height:8),
      if(role==UserRole.citizen)_InfoTile(icon:Icons.add_a_photo_outlined,title:'Reportar con fotografía',subtitle:'Toma una foto o elige una de la galería, marca la ubicación y envía el reporte.',onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ReportForm(store:store,createdBy:userId)))),
      if(role!=UserRole.citizen)_InfoTile(icon:Icons.alt_route,title:'Rutas y horarios por brigada',subtitle:'Consulta recorridos por brigada, paradas y horarios de atención.',onTap:()=>onNavigate(3)),
      _InfoTile(icon:Icons.place_outlined,title:'Ver puntos en Cusco',subtitle:'Explora las incidencias y las zonas de recolección en el mapa.',onTap:()=>onNavigate(1)),
      if(role==UserRole.municipal)_InfoTile(icon:Icons.assignment_turned_in_outlined,title:'Gestionar reportes y brigadas',subtitle:'Asigna equipos, prioriza incidencias y actualiza sus estados.',onTap:()=>onNavigate(4)),
      if(role==UserRole.collector)_InfoTile(icon:Icons.local_shipping_outlined,title:'Seguimiento del recolector',subtitle:'Consulta puntos asignados y márcalos como atendidos.',onTap:()=>onNavigate(4)),
      const SizedBox(height:10),
    ]);
  }
}
class _Metric extends StatelessWidget {final String label,value;final IconData icon; const _Metric({required this.label,required this.value,required this.icon});
  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[Icon(icon,color:_green),const SizedBox(height:6),Text(value,style:const TextStyle(fontSize:23,fontWeight:FontWeight.bold)),Text(label,textAlign:TextAlign.center,style:const TextStyle(fontSize:11))])));}
class _InfoTile extends StatelessWidget {final IconData icon;final String title,subtitle;final VoidCallback onTap;
  const _InfoTile({required this.icon,required this.title,required this.subtitle,required this.onTap});
  @override Widget build(BuildContext context)=>Card(child:ListTile(onTap:onTap,leading:CircleAvatar(backgroundColor:const Color(0xFFE6F3EC),child:Icon(icon,color:_green)),title:Text(title,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text(subtitle),trailing:const Icon(Icons.chevron_right)));}

Future<Position?> askLocation(BuildContext context) async {
  try {
    // Solicita el permiso antes de consultar la posición.
    var permission=await Geolocator.checkPermission();
    if(permission==LocationPermission.denied) {
      permission=await Geolocator.requestPermission();
    }
    if(permission==LocationPermission.deniedForever) {
      if(context.mounted)_show(context,'Ubicación bloqueada. Usa «Permisos de app» para habilitarla.');
      return null;
    }
    if(permission==LocationPermission.denied) {
      if(context.mounted)_show(context,'Permiso de ubicación denegado. Puedes autorizarlo en ajustes.');
      return null;
    }
    if(!await Geolocator.isLocationServiceEnabled()) {
      if(context.mounted)_show(context,'El GPS está desactivado. Toca «Activar GPS».');
      return null;
    }
    return await Geolocator.getCurrentPosition(
      locationSettings:const LocationSettings(
        accuracy:LocationAccuracy.high,timeLimit:Duration(seconds:25)));
  } catch(e) {
    if(context.mounted)_show(context,'No se obtuvo ubicación: $e');
    return null;
  }
}

void _show(BuildContext c,String message){ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text(message)));}
Color statusColor(String value)=>switch(value){'Solucionado'=>const Color(0xFF2E8A56),'En atención'=>const Color(0xFFE08A28),'En verificación'=>const Color(0xFF7B67AC),_=>const Color(0xFFD05C50)};

class GpsPermissionCard extends StatelessWidget {
  final VoidCallback? onLocation;
  final bool loading;
  final String? status;
  const GpsPermissionCard({super.key,this.onLocation,this.loading=false,this.status});
  @override Widget build(BuildContext context) => Card(
    child: Padding(padding:const EdgeInsets.all(15),child:Column(
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const Row(children:[Icon(Icons.gps_fixed,color:_green),SizedBox(width:8),
          Expanded(child:Text('Ubicación y permisos',style:TextStyle(fontWeight:FontWeight.bold,fontSize:17)))]),
        const SizedBox(height:8),
        Text(status??'Presiona Mi ubicación. Android solicitará el permiso cuando sea necesario.'),
        const SizedBox(height:10),
        FilledButton.icon(onPressed:loading?null:onLocation,
          icon: loading?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.my_location),
          label:const Text('Mi ubicación')),
        Wrap(alignment:WrapAlignment.spaceBetween,spacing:6,children:[
          TextButton.icon(onPressed:()=>Geolocator.openLocationSettings(),icon:const Icon(Icons.settings),label:const Text('Activar GPS')),
          TextButton.icon(onPressed:()=>Geolocator.openAppSettings(),icon:const Icon(Icons.admin_panel_settings_outlined),label:const Text('Permisos de app')),
        ]),
      ])));
}

class ReportsMapView extends StatefulWidget {final DataStore store;const ReportsMapView({super.key,required this.store});@override State<ReportsMapView> createState()=>_ReportsMapViewState();}
class _ReportsMapViewState extends State<ReportsMapView> {
  final controller=MapController();
  bool pointsOnly=false,getting=false;
  LatLng? me; String? gpsStatus;
  Future<void> locate() async {
    setState(() {getting=true;gpsStatus='Consultando el GPS del teléfono...';});
    final pos=await askLocation(context);
    if(!mounted)return;
    setState(() {getting=false;if(pos!=null)me=LatLng(pos.latitude,pos.longitude);
      gpsStatus=pos==null?'No se obtuvo ubicación. Revisa permisos o servicio GPS.':
       'Ubicación detectada · precisión ${pos.accuracy.toStringAsFixed(0)} m';});
    if(pos!=null)controller.move(LatLng(pos.latitude,pos.longitude),16);
  }
  @override Widget build(BuildContext context){
    final reports=widget.store.reports.where((r)=>!pointsOnly||r.status!='Solucionado').toList();
    return Column(children:[
      Padding(padding:const EdgeInsets.symmetric(horizontal:10),child:GpsPermissionCard(onLocation:locate,loading:getting,status:gpsStatus)),
      Padding(padding:const EdgeInsets.fromLTRB(14,8,14,8),child:Row(children:[const Expanded(child:Text('Mapa de incidencias',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800))),
        IconButton(tooltip:'Mi ubicación',onPressed:getting?null:locate,icon:getting?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.my_location)),
        IconButton(tooltip:'Acercar',onPressed:()=>controller.move(controller.camera.center,controller.camera.zoom+1),icon:const Icon(Icons.add)),
        IconButton(tooltip:'Alejar',onPressed:()=>controller.move(controller.camera.center,controller.camera.zoom-1),icon:const Icon(Icons.remove))])),
      Padding(padding:const EdgeInsets.symmetric(horizontal:14),child:Row(children:[const Expanded(child:Text('Solo pendientes / en atención')),Switch(value:pointsOnly,onChanged:(v)=>setState(()=>pointsOnly=v))])),
      Expanded(child:FlutterMap(mapController:controller,options:const MapOptions(initialCenter:_center,initialZoom:12.6),children:[
        TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'com.unsaac.cusco_limpio_flutter'),
        MarkerLayer(markers:[for(final r in reports)Marker(point:r.location,width:46,height:50,child:GestureDetector(onTap:()=>_reportDetail(context,widget.store,r),child:Tooltip(message:r.address,child:Icon(Icons.location_on,size:44,color:statusColor(r.status))))),
          if(me!=null) Marker(point:me!,width:34,height:34,child:const Icon(Icons.my_location,color:Colors.blue,size:31))]),
        const SimpleAttributionWidget(source:Text('© OpenStreetMap contributors')),
      ])),
      Padding(padding:const EdgeInsets.symmetric(horizontal:15,vertical:7),child:Wrap(spacing:10,runSpacing:6,children:[for(final s in ['Pendiente','En verificación','En atención','Solucionado'])Row(mainAxisSize:MainAxisSize.min,children:[CircleAvatar(radius:5,backgroundColor:statusColor(s)),const SizedBox(width:4),Text(s,style:const TextStyle(fontSize:11))])])),
    ]);
  }
}

class ReportsView extends StatefulWidget {final DataStore store;final UserRole role;final String userId,brigade;const ReportsView({super.key,required this.store,required this.role,required this.userId,required this.brigade});@override State<ReportsView> createState()=>_ReportsViewState();}
class _ReportsViewState extends State<ReportsView> {
  String filter='Todos';
  @override Widget build(BuildContext context){final records=widget.store.reports.where((r)=>(filter=='Todos'||r.status==filter) && (widget.role==UserRole.citizen?(r.createdBy==widget.userId||r.createdBy=='demo'):widget.role==UserRole.collector?r.collector==widget.brigade:true)).toList();
    return Scaffold(body:Column(children:[Padding(padding:const EdgeInsets.all(14),child:Row(children:[Expanded(child:Text(widget.role==UserRole.citizen?'Mis reportes':widget.role==UserRole.collector?'Reportes de mi brigada':'Bandeja de incidencias',style:const TextStyle(fontSize:19,fontWeight:FontWeight.w800))),if(widget.role==UserRole.citizen)FilledButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ReportForm(store:widget.store,createdBy:widget.userId))),icon:const Icon(Icons.add),label:const Text('Nuevo'))])),
      SizedBox(height:46,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:12),children:[for(final s in ['Todos','Pendiente','En verificación','En atención','Solucionado'])Padding(padding:const EdgeInsets.only(right:6),child:ChoiceChip(label:Text(s),selected:filter==s,onSelected:(_)=>setState(()=>filter=s)))])),
      Expanded(child:ListView.builder(padding:const EdgeInsets.all(12),itemCount:records.length,itemBuilder:(_,i)=>ReportCard(report:records[i],onTap:()=>_reportDetail(context,widget.store,records[i]))))]));
  }
}
class ReportCard extends StatelessWidget {final CleanReport report;final VoidCallback onTap;const ReportCard({super.key,required this.report,required this.onTap});
  @override Widget build(BuildContext context)=>Card(child:InkWell(borderRadius:BorderRadius.circular(18),onTap:onTap,child:Padding(padding:const EdgeInsets.all(12),child:Row(children:[ClipRRect(borderRadius:BorderRadius.circular(10),child:reportPhoto(report.photo,width:83,height:90)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(report.id,style:const TextStyle(fontWeight:FontWeight.bold)),Text(report.address,maxLines:2,overflow:TextOverflow.ellipsis),Text('${report.district} · ${dateLabel(report.createdAt)} · ${report.type}',style:const TextStyle(fontSize:12,color:Colors.black54)),const SizedBox(height:5),Text(report.status,style:TextStyle(color:statusColor(report.status),fontWeight:FontWeight.bold))])),const Icon(Icons.chevron_right)]))));
}
void _reportDetail(BuildContext context,DataStore store,CleanReport r){showModalBottomSheet(context:context,isScrollControlled:true,showDragHandle:true,builder:(_)=>SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(20,0,20,24),child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${r.id} · ${r.status}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:19)),const SizedBox(height:10),Text(r.address,style:const TextStyle(fontWeight:FontWeight.w700)),Text('${r.district} · ${r.type} · Registrado ${dateLabel(r.createdAt)}'),const SizedBox(height:10),Text(r.description),const SizedBox(height:8),Text('Prioridad: ${r.priority} · Personal: ${r.collector}'),Text('Coordenadas: ${r.lat}, ${r.lng}'),const SizedBox(height:12),ClipRRect(borderRadius:BorderRadius.circular(12),child:reportPhoto(r.photo,height:180,width:double.infinity)),const SizedBox(height:6),Text((r.photo.startsWith('file:')||r.photo.startsWith('data:'))?'Fotografía adjuntada desde el dispositivo.':'Imagen de referencia del reporte.',style:const TextStyle(fontSize:11,color:Colors.black54))])))));}

class ReportForm extends StatefulWidget {final DataStore store;final String createdBy;const ReportForm({super.key,required this.store,this.createdBy='citizen'});@override State<ReportForm> createState()=>_ReportFormState();}
class _ReportFormState extends State<ReportForm> {
  final form=GlobalKey<FormState>();
  final desc=TextEditingController(),address=TextEditingController();
  final picker=ImagePicker();
  String district='Cusco',type='Domésticos';
  LatLng? picked;
  XFile? captured;
  final map=MapController();
  bool busy=false,gettingGps=false;
  String gpsStatus='Marca el lugar en el mapa o solicita tu ubicación.';

  @override void dispose(){desc.dispose();address.dispose();map.dispose();super.dispose();}

  Future<void> position() async {
    if(gettingGps)return;
    setState((){gettingGps=true;gpsStatus='Consultando ubicación...';});
    final pos=await askLocation(context);
    if(!mounted)return;
    setState((){
      gettingGps=false;
      gpsStatus=pos==null?'Sin posición. Revisa los permisos.':
       'Posición recibida (precisión ${pos.accuracy.toStringAsFixed(0)} m)';
      if(pos!=null)picked=LatLng(pos.latitude,pos.longitude);
    });
    if(pos!=null)map.move(LatLng(pos.latitude,pos.longitude),16);
  }

  Future<void> chooseImage(ImageSource source) async {
    try {
      final photo=await picker.pickImage(source:source,imageQuality:82,maxWidth:1600);
      if(photo!=null && mounted)setState(()=>captured=photo);
    } catch(e) {
      if(mounted)_show(context,'No se pudo abrir la cámara o galería: $e');
    }
  }

  Future<void> submit() async {
    if(!form.currentState!.validate())return;
    if(picked==null){_show(context,'Selecciona la ubicación del reporte.');return;}
    if(captured==null){_show(context,'Adjunta una fotografía tomada con la cámara o galería.');return;}
    setState(()=>busy=true);
    try {
      // Copia fuera de la carpeta temporal de image_picker para mantenerla en el teléfono.
      String savedPhoto;
      if (kIsWeb) {
        savedPhoto='data:${base64Encode(await captured!.readAsBytes())}';
      } else {
        final directory=await getApplicationDocumentsDirectory();
        final photoDir=Directory('${directory.path}/fotos_reportes');
        await photoDir.create(recursive:true);
        final file=await File(captured!.path).copy('${photoDir.path}/reporte_${DateTime.now().microsecondsSinceEpoch}.jpg');
        savedPhoto='file:${file.path}';
      }
      final r=CleanReport(id:'CUS-${DateTime.now().millisecondsSinceEpoch}',
        district:district,address:address.text.trim(),description:desc.text.trim(),
        type:type,photo:savedPhoto,status:'Pendiente',priority:'Media',
        collector:'Sin asignar',createdBy:widget.createdBy,lat:picked!.latitude,lng:picked!.longitude,createdAt:DateTime.now());
      await widget.store.add(r);
      if(mounted){Navigator.pop(context);}
    } catch(e){if(mounted)_show(context,'No se pudo guardar el reporte: $e');}
    finally {if(mounted)setState(()=>busy=false);}
  }

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Nuevo reporte con foto')),
    body:Form(key:form,child:ListView(padding:const EdgeInsets.all(16),children:[
      const Text('1. Fotografía del problema',style:TextStyle(fontWeight:FontWeight.bold,fontSize:19)),
      const Text('Registra lo que está ocurriendo: residuos, escombros o contenedores llenos.'),
      const SizedBox(height:12),
      if(captured!=null)ClipRRect(borderRadius:BorderRadius.circular(14),
        child:FutureBuilder<Uint8List>(future:captured!.readAsBytes(),builder:(context,snapshot)=>snapshot.hasData?Image.memory(snapshot.data!,height:185,fit:BoxFit.cover):const SizedBox(height:185,child:Center(child:CircularProgressIndicator()))))
      else Container(height:125,alignment:Alignment.center,
        decoration:BoxDecoration(color:const Color(0xFFE6F2EE),borderRadius:BorderRadius.circular(14)),
        child:const Column(mainAxisAlignment:MainAxisAlignment.center,children:[
          Icon(Icons.add_a_photo_outlined,size:42,color:_green),Text('Todavía no hay fotografía')])) ,
      const SizedBox(height:10),
      Wrap(spacing:8,runSpacing:8,children:[
        FilledButton.icon(onPressed:()=>chooseImage(ImageSource.camera),
          icon:const Icon(Icons.camera_alt_outlined),label:const Text('Tomar foto')),
        OutlinedButton.icon(onPressed:()=>chooseImage(ImageSource.gallery),
          icon:const Icon(Icons.photo_library_outlined),label:const Text('Elegir de galería')),
      ]),
      const SizedBox(height:22),
      const Text('2. Ubicación del reporte',style:TextStyle(fontWeight:FontWeight.bold,fontSize:19)),
      const Text('Toca el lugar exacto en el mapa o utiliza el GPS del celular.'),
      GpsPermissionCard(onLocation:position,loading:gettingGps,status:gpsStatus),
      SizedBox(height:245,child:ClipRRect(borderRadius:BorderRadius.circular(17),
        child:FlutterMap(mapController:map,options:MapOptions(initialCenter:_center,initialZoom:12,
          onTap:(_,point)=>setState(()=>picked=point)),children:[
          TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName:'com.unsaac.cusco_limpio_flutter'),
          if(picked!=null)MarkerLayer(markers:[Marker(point:picked!,
            width:48,height:48,child:const Icon(Icons.location_on,color:Colors.red,size:42))]),
          const SimpleAttributionWidget(source:Text('© OpenStreetMap contributors')),
        ]))),
      const SizedBox(height:9),
      Text(picked==null?'Ubicación pendiente':
        'Coordenadas: ${picked!.latitude.toStringAsFixed(5)}, ${picked!.longitude.toStringAsFixed(5)}'),
      const SizedBox(height:18),
      const Text('3. Información del problema',style:TextStyle(fontWeight:FontWeight.bold,fontSize:19)),
      TextFormField(controller:address,decoration:const InputDecoration(
        labelText:'Dirección o referencia',border:OutlineInputBorder()),
        validator:(v)=>(v?.trim().isEmpty??true)?'Introduce una referencia':null),
      const SizedBox(height:12),
      DropdownButtonFormField<String>(initialValue:district,
        decoration:const InputDecoration(labelText:'Distrito',border:OutlineInputBorder()),
        items:['Cusco','Wanchaq','San Sebastián','San Jerónimo','Santiago']
          .map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),
        onChanged:(v)=>setState(()=>district=v!)),
      const SizedBox(height:12),
      DropdownButtonFormField<String>(initialValue:type,
        decoration:const InputDecoration(labelText:'Tipo de residuo',border:OutlineInputBorder()),
        items:['Domésticos','Plásticos','Orgánicos','Escombros','Otros']
          .map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),
        onChanged:(v)=>setState(()=>type=v!)),
      const SizedBox(height:12),
      TextFormField(controller:desc,maxLines:3,decoration:const InputDecoration(
        labelText:'Descripción',border:OutlineInputBorder()),
        validator:(v)=>(v?.trim().length??0)<10?'Describe el problema con al menos 10 caracteres':null),
      const SizedBox(height:18),
      FilledButton.icon(onPressed:busy?null:submit,icon:const Icon(Icons.send_outlined),
        label:Text(busy?'Guardando...':'Registrar reporte')),
      const SizedBox(height:8),
      const Text('Almacenamiento local: la foto y el reporte se guardan en este teléfono; '
        'aún no se sincronizan con otros usuarios.',style:TextStyle(fontSize:12,color:Colors.black54)),
    ])));
}

class ManagementView extends StatelessWidget {final DataStore store;final UserRole role;const ManagementView({super.key,required this.store,required this.role});
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(14),children:[const Text('Operaciones municipales',style:TextStyle(fontWeight:FontWeight.w800,fontSize:21)),const SizedBox(height:10),if(role==UserRole.citizen)const Card(child:Padding(padding:EdgeInsets.all(16),child:Text('Cambia al perfil Municipalidad desde la parte superior para asignar brigadas y actualizar estados.'))),
    for(final r in store.reports)Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${r.id} · ${r.address}',style:const TextStyle(fontWeight:FontWeight.bold)),Text('Estado: ${r.status} · ${r.district}'),const SizedBox(height:9),
      DropdownButtonFormField<String>(initialValue:r.collector,decoration:const InputDecoration(labelText:'Brigada asignada',border:OutlineInputBorder()),items:['Sin asignar','Brigada 01','Brigada 02','Brigada 03'].map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),onChanged:role==UserRole.municipal?(s){if(s!=null)store.assign(r,s);}:null),const SizedBox(height:9),
      DropdownButtonFormField<String>(initialValue:r.priority,decoration:const InputDecoration(labelText:'Prioridad operativa',border:OutlineInputBorder()),items:['Baja','Media','Alta'].map((value)=>DropdownMenuItem(value:value,child:Text(value))).toList(),onChanged:role==UserRole.municipal?(value){if(value!=null)store.setPriority(r,value);}:null),const SizedBox(height:9),
      DropdownButtonFormField<String>(initialValue:r.status,decoration:const InputDecoration(labelText:'Estado del reporte',border:OutlineInputBorder()),items:['Pendiente','En verificación','En atención','Solucionado'].map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),onChanged:role==UserRole.municipal?(s){if(s!=null)store.status(r,s);}:null),
      const SizedBox(height:9),ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.note_alt_outlined),title:Text(store.notes[r.id]??'Sin observación operativa'),trailing:IconButton(icon:const Icon(Icons.edit_note),tooltip:'Registrar observación',onPressed:role==UserRole.municipal?()=>_municipalNote(context,store,r):null)),
    ]))),const SizedBox(height:15),OutlinedButton.icon(onPressed:role==UserRole.municipal?()=>_confirmReset(context,store):null,icon:const Icon(Icons.restart_alt),label:const Text('Restablecer datos iniciales'))]);
}
Future<void> _municipalNote(BuildContext context,DataStore store,CleanReport report) async {
  final controller=TextEditingController(text:store.notes[report.id]??'');
  final value=await showDialog<String>(context:context,builder:(dialog)=>AlertDialog(title:Text('Observación · ${report.id}'),content:TextField(controller:controller,maxLines:3,maxLength:250,decoration:const InputDecoration(hintText:'Acción requerida, seguimiento o verificación')),actions:[TextButton(onPressed:()=>Navigator.pop(dialog),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(dialog,controller.text.trim()),child:const Text('Guardar'))]));
  if(value!=null && value.isNotEmpty)await store.addNote(report,value);
  controller.dispose();
}
void _confirmReset(BuildContext context,DataStore store) async {final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Restablecer datos'),content:const Text('Se perderán los cambios guardados en este dispositivo.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Restablecer'))]));if(yes==true)await store.reset();}

// Incorpora cada incidencia al trazado de su brigada. Se inserta una visita
// exactamente sobre las coordenadas del reporte, no un marcador aislado.
// La geometría conecta puntos; no pretende ser una navegación por calles.
List<LatLng> routeWithReports(DemoRoute route, Iterable<CleanReport> reports) {
  final result = <LatLng>[...route.waypoints];
  final pending = reports.where((r) => r.collector == route.brigade && r.status != 'Solucionado').toList();
  for (final report in pending) {
    final target = report.location;
    if (result.any((p) => p.latitude == target.latitude && p.longitude == target.longitude)) continue;
    int closestSegment = 0;
    double best = double.infinity;
    for (int i = 0; i < result.length - 1; i++) {
      final a = result[i], b = result[i + 1];
      // Distancia en coordenadas proyectadas localmente, suficiente para
      // decidir dónde añadir una parada en el mapa (no distancia vial).
      const latitudeScale = 0.972;
      final dx = (b.longitude - a.longitude) * latitudeScale;
      final dy = b.latitude - a.latitude;
      final px = (target.longitude - a.longitude) * latitudeScale;
      final py = target.latitude - a.latitude;
      final denom = dx * dx + dy * dy;
      final t = denom == 0 ? 0.0 : ((px * dx + py * dy) / denom).clamp(0.0, 1.0);
      final ex = px - t * dx;
      final ey = py - t * dy;
      final distance = ex * ex + ey * ey;
      if (distance < best) {best = distance; closestSegment = i;}
    }
    result.insert(closestSegment + 1, target);
  }
  return result;
}

LatLng routeCenter(List<LatLng> points) {
  if(points.isEmpty) return _center;
  final lat = points.map((p)=>p.latitude).reduce((a,b)=>a+b)/points.length;
  final lng = points.map((p)=>p.longitude).reduce((a,b)=>a+b)/points.length;
  return LatLng(lat,lng);
}

class CollectorView extends StatefulWidget {final DataStore store;final String brigade;const CollectorView({super.key,required this.store,required this.brigade});@override State<CollectorView> createState()=>_CollectorViewState();}
class _CollectorViewState extends State<CollectorView> {
  late String selected;final controller=MapController();
  @override void initState(){super.initState();selected=widget.brigade.isEmpty?'Brigada 01':widget.brigade;}
  @override void dispose(){controller.dispose();super.dispose();}
  LatLng? me;bool busy=false;
  List<CleanReport> get assigned=>widget.store.reports.where((r)=>r.collector==selected && r.status!='Solucionado').toList();
  Future<void> locate() async {setState(()=>busy=true);final p=await askLocation(context);if(!mounted)return;setState((){busy=false;if(p!=null)me=LatLng(p.latitude,p.longitude);});if(me!=null)controller.move(me!,15);}
  @override Widget build(BuildContext context){final points=assigned;final remaining=points.where((r)=>!widget.store.collected.contains(r.id)).toList();final route=routeForBrigade(selected);final trip=route==null?<LatLng>[]:routeWithReports(route,widget.store.reports);
    return ListView(padding:const EdgeInsets.all(14),children:[const Text('Recolector · puntos asignados',style:TextStyle(fontSize:21,fontWeight:FontWeight.w800)),const SizedBox(height:5),const SizedBox(height:12),
      Card(child:ListTile(leading:const Icon(Icons.local_shipping),title:Text('Mi brigada: $selected'),subtitle:const Text('Turno asignado al perfil actual'))),const SizedBox(height:12),
      Card(child:Padding(padding:const EdgeInsets.all(15),child:Row(children:[const Icon(Icons.route,color:_green,size:32),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${points.length} puntos asignados',style:const TextStyle(fontWeight:FontWeight.bold)),Text('${remaining.length} pendientes de atención')]))]))),const SizedBox(height:10),
      if(route!=null)Card(color:const Color(0xFFEAF6EF),child:Padding(padding:const EdgeInsets.all(13),child:Row(children:[const Icon(Icons.check_circle_outline,color:_green),const SizedBox(width:10),Expanded(child:Text('Recorrido actualizado: ${route.stops.length} paradas del sector y ${points.length} incidencias conectadas al trazado.',style:const TextStyle(fontWeight:FontWeight.w600)))]))),
      const SizedBox(height:8),
      SizedBox(height:350,child:ClipRRect(borderRadius:BorderRadius.circular(17),child:FlutterMap(mapController:controller,options:MapOptions(initialCenter:routeCenter(trip),initialZoom:11.5),children:[
        TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'com.unsaac.cusco_limpio_flutter'),
        if(trip.length>1)PolylineLayer(polylines:[Polyline(points:trip,strokeWidth:6,color:_green)]),
        MarkerLayer(markers:[for(int i=0;i<points.length;i++)Marker(point:points[i].location,width:44,height:44,child:GestureDetector(onTap:()=>_reportDetail(context,widget.store,points[i]),child:CircleAvatar(backgroundColor:widget.store.collected.contains(points[i].id)?Colors.grey:_green,child:Text('${i+1}',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold))))),if(me!=null)Marker(point:me!,child:const Icon(Icons.my_location,color:Colors.blue,size:35))]),
        const SimpleAttributionWidget(source:Text('© OpenStreetMap contributors')),
      ]))),
      Padding(padding:const EdgeInsets.symmetric(vertical:6),child:Row(children:[Expanded(child:OutlinedButton.icon(onPressed:busy?null:locate,icon:const Icon(Icons.my_location),label:Text(busy?'Localizando...':'Mi ubicación'))),const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:trip.isEmpty?null:()=>controller.fitCamera(CameraFit.bounds(bounds:LatLngBounds.fromPoints(trip),padding:const EdgeInsets.all(38))),icon:const Icon(Icons.center_focus_strong),label:const Text('Ver ruta completa')))])),
      const Text('Atención de mi brigada',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
      const Padding(padding:EdgeInsets.only(top:3,bottom:6),child:Text('Cada marcador numerado está incluido en el recorrido verde.',style:TextStyle(color:_green,fontSize:12))),
      if(points.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(20),child:Text('Esta brigada no tiene reportes activos asignados. Cambia de brigada o asigna reportes desde Municipalidad.'))),
      for(int i=0;i<points.length;i++)Card(child:CheckboxListTile(value:widget.store.collected.contains(points[i].id),onChanged:(_) async {await widget.store.toggleCollected(points[i].id); if(widget.store.collected.contains(points[i].id)) await widget.store.status(points[i],'En verificación');},secondary:CircleAvatar(child:Text('${i+1}')),title:Text(points[i].address),subtitle:Text('${points[i].district} · ${points[i].id} · ${points[i].status}\nToca para marcar el punto como atendido'),isThreeLine:true)),
      const SizedBox(height:8),const Text('La línea conecta las paradas y reportes asignados; aún no calcula giros por calles. La ubicación se consulta cuando pulsas Mi ubicación.',style:TextStyle(fontSize:12,color:Colors.black54)),
    ]);
  }
}



// Registro local de movimientos; accesible al administrador, no al público.
class AuditView extends StatelessWidget {
  final DataStore store;
  const AuditView({super.key,required this.store});
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[
    const Text('Bitácora del sistema',style:TextStyle(fontSize:24,fontWeight:FontWeight.w800)),
    const SizedBox(height:5),const Text('Historial de cambios de reportes, prioridades, brigadas y atención.',style:TextStyle(color:Colors.black54)),
    const SizedBox(height:13),if(store.audit.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(18),child:Text('Aún no hay movimientos registrados. Modifica una asignación o crea una incidencia para generar eventos.'))),
    for(final event in store.audit)Card(child:ListTile(leading:const Icon(Icons.history,color:Color(0xFF345983)),title:Text(event,style:const TextStyle(fontSize:13)))),
  ]);
}

class UserManagementView extends StatefulWidget {
  final DemoAuth auth;
  final DataStore store;
  const UserManagementView({super.key,required this.auth,required this.store});
  @override State<UserManagementView> createState()=>_UserManagementViewState();
}
class _UserManagementViewState extends State<UserManagementView> {
  String search='';
  @override Widget build(BuildContext context) {
    final users=widget.auth.users.where((u)=>'${u.name} ${u.email}'.toLowerCase().contains(search.toLowerCase())).toList();
    return Scaffold(appBar:AppBar(title:const Text('Usuarios y permisos')),
      body:ListView(padding:const EdgeInsets.all(16),children:[
        Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:const Color(0xFFE8EFFA),borderRadius:BorderRadius.circular(18)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Administración de accesos',style:TextStyle(fontWeight:FontWeight.w800,fontSize:21)),SizedBox(height:5),Text('Asigna roles, vincula recolectores a brigadas y habilita o deshabilita cuentas locales.') ])),
        const SizedBox(height:13),TextField(onChanged:(v)=>setState(()=>search=v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'Buscar por nombre o correo',border:OutlineInputBorder())),
        const SizedBox(height:12),
        for(final user in users)Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[CircleAvatar(child:Icon(user.role=='admin'?Icons.admin_panel_settings:user.role=='municipal'?Icons.account_balance:user.role=='collector'?Icons.local_shipping:Icons.person)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(user.name,style:const TextStyle(fontWeight:FontWeight.bold)),Text(user.email,style:const TextStyle(fontSize:12))])),Chip(label:Text(user.active?'Activo':'Inactivo'))]),
          const SizedBox(height:9),DropdownButtonFormField<String>(key:ValueKey('${user.id}-${user.role}'),initialValue:user.role,decoration:const InputDecoration(border:OutlineInputBorder(),labelText:'Rol'),items:const [DropdownMenuItem(value:'citizen',child:Text('Ciudadano')),DropdownMenuItem(value:'collector',child:Text('Recolector')),DropdownMenuItem(value:'municipal',child:Text('Municipalidad')),DropdownMenuItem(value:'admin',child:Text('Administrador'))],onChanged:(v) async {if(v!=null){final result=await widget.auth.updateUser(user.id,role:v);if(result==null){widget.store.record('Administrador','Cambió el rol de ${user.email} a $v');await widget.store.save();}else if(context.mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(result)));}setState((){});}}),
          if(user.role=='collector')... [const SizedBox(height:8),DropdownButtonFormField<String>(key:ValueKey('${user.id}-${user.brigade}'),initialValue:['Brigada 01','Brigada 02','Brigada 03'].contains(user.brigade)?user.brigade:'Brigada 01',decoration:const InputDecoration(labelText:'Brigada del trabajador',border:OutlineInputBorder()),items:['Brigada 01','Brigada 02','Brigada 03'].map((b)=>DropdownMenuItem(value:b,child:Text(b))).toList(),onChanged:(v) async {if(v!=null){await widget.auth.updateUser(user.id,brigade:v);widget.store.record('Administrador','Asignó usuario ${user.email} a $v');await widget.store.save();setState((){});}})],
          SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Cuenta habilitada'),value:user.active,onChanged:(v) async {final result=await widget.auth.updateUser(user.id,active:v);if(result==null){widget.store.record('Administrador','Cuenta ${user.email}: ${v?'activada':'desactivada'}');await widget.store.save();}else if(context.mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(result)));}setState((){});}),
        ]))),
        const SizedBox(height:12),const Text('Los accesos son locales y demostrativos. Para uso real, estas operaciones requieren autenticación y autorización del servidor.',style:TextStyle(fontSize:12,color:Colors.black54)),
      ]));
  }
}

// ================================================================
// PLANIFICACIÓN DIDÁCTICA. Coordenadas/recorridos aproximados, NO
// verificados sobre red vial. Para navegación real usar servicio de
// rutas (OSRM/GraphHopper) y datos oficiales de la municipalidad.
// ================================================================
String dateLabel(DateTime value) => '${value.day.toString().padLeft(2,'0')}/${value.month.toString().padLeft(2,'0')}/${value.year}';

class DemoRoute {
  final String id, name, brigade, days, hours, zone, description;
  final Color color;
  final List<LatLng> waypoints;
  final List<String> stops;
  const DemoRoute({required this.id,required this.name,required this.brigade,
    required this.days,required this.hours,required this.zone,
    required this.description,required this.color,required this.waypoints,required this.stops});
}

const demonstrationRoutes=<DemoRoute>[
  DemoRoute(id:'R-01',name:'Centro · Wanchaq · Magisterio',brigade:'Brigada 01',days:'Lunes, miércoles y viernes',hours:'06:00 – 10:00',zone:'Centro / Wanchaq / Magisterio',
    description:'Corredor extendido por sectores del centro, Wanchaq y Magisterio. Coordenadas aproximadas para explorar el recorrido.',color:Color(0xFF13956C),
    waypoints:[LatLng(-13.5163,-71.9781),LatLng(-13.5181,-71.9772),LatLng(-13.5202,-71.9763),LatLng(-13.5224,-71.9752),LatLng(-13.5243,-71.9735),LatLng(-13.5258,-71.9709),LatLng(-13.5267,-71.9681),LatLng(-13.5261,-71.9650),LatLng(-13.5248,-71.9621),LatLng(-13.5230,-71.9600),LatLng(-13.5214,-71.9581),LatLng(-13.5228,-71.9554),LatLng(-13.5252,-71.9530),LatLng(-13.5274,-71.9524),LatLng(-13.5293,-71.9544),LatLng(-13.5300,-71.9575),LatLng(-13.5290,-71.9590)],
    stops:['Plaza de Armas','Av. El Sol · norte','Coricancha','Av. El Sol · sur','Estación Wanchaq','Av. La Cultura · inicio','Magisterio','Mercado Wanchaq']),
  DemoRoute(id:'R-02',name:'Wanchaq · San Sebastián · San Jerónimo',brigade:'Brigada 02',days:'Martes, jueves y sábado',hours:'07:00 – 12:00',zone:'Wanchaq / San Sebastián / San Jerónimo',
    description:'Corredor extendido hacia el suroriente del área urbana, con paradas distribuidas por sectores.',color:Color(0xFF386ED2),
    waypoints:[LatLng(-13.5290,-71.9590),LatLng(-13.5279,-71.9556),LatLng(-13.5262,-71.9519),LatLng(-13.5255,-71.9487),LatLng(-13.5269,-71.9460),LatLng(-13.5282,-71.9424),LatLng(-13.5298,-71.9390),LatLng(-13.5309,-71.9357),LatLng(-13.5320,-71.9316),LatLng(-13.5327,-71.9267),LatLng(-13.5334,-71.9217),LatLng(-13.5354,-71.9166),LatLng(-13.5381,-71.9122),LatLng(-13.5400,-71.9074),LatLng(-13.5420,-71.9027),LatLng(-13.5445,-71.8984),LatLng(-13.5458,-71.8930),LatLng(-13.5473,-71.8861)],
    stops:['Mercado Wanchaq','Av. La Cultura','Universidad Andina · sector','San Sebastián · ingreso','Plaza San Sebastián','Larapa · sector','Angostura · sector','San Jerónimo']),
  DemoRoute(id:'R-03',name:'Santiago · Centro · Ttio',brigade:'Brigada 03',days:'Lunes a sábado',hours:'14:00 – 19:00',zone:'Santiago / Centro / Ttio',
    description:'Circuito ampliado entre Santiago, centro urbano y Wanchaq, destinado a practicar la atención de puntos.',color:Color(0xFFDF8433),
    waypoints:[LatLng(-13.5394,-71.9901),LatLng(-13.5364,-71.9895),LatLng(-13.5339,-71.9874),LatLng(-13.5314,-71.9853),LatLng(-13.5298,-71.9822),LatLng(-13.5275,-71.9814),LatLng(-13.5251,-71.9791),LatLng(-13.5238,-71.9752),LatLng(-13.5200,-71.9765),LatLng(-13.5163,-71.9781),LatLng(-13.5188,-71.9754),LatLng(-13.5221,-71.9727),LatLng(-13.5258,-71.9709),LatLng(-13.5291,-71.9682),LatLng(-13.5327,-71.9662),LatLng(-13.5351,-71.9640),LatLng(-13.5341,-71.9593),LatLng(-13.5311,-71.9574)],
    stops:['Santiago · sector sur','Plaza Santiago','Av. Grau','Puente Almudena · sector','Centro Histórico','Av. El Sol','Estación Wanchaq','Ttio · sector']),
];
DemoRoute? routeForBrigade(String brigade) {
  for(final route in demonstrationRoutes) {if(route.brigade==brigade)return route;}
  return null;
}

class _HistorySummary extends StatelessWidget {
  final DataStore store;
  const _HistorySummary({required this.store});
  @override Widget build(BuildContext context){
    final ordered=[...store.reports]..sort((a,b)=>b.createdAt.compareTo(a.createdAt));
    final recent=ordered.take(3).toList();
    return Card(child:Padding(padding:const EdgeInsets.all(15),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Row(children:[Icon(Icons.history_toggle_off,color:_green),SizedBox(width:9),Text('Actividad reciente',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold))]),
      const SizedBox(height:6),for(final r in recent)ListTile(dense:true,contentPadding:EdgeInsets.zero,
        title:Text(r.address,maxLines:1,overflow:TextOverflow.ellipsis),
        subtitle:Text('${dateLabel(r.createdAt)} · ${r.district}'),
        trailing:Text(r.status,style:TextStyle(fontSize:11,color:statusColor(r.status))),
      ),
    ])));
  }
}

class RoutesView extends StatefulWidget {
  final DataStore store;
  const RoutesView({super.key,required this.store});
  @override State<RoutesView> createState()=>_RoutesViewState();
}
class _RoutesViewState extends State<RoutesView> {
  int chosen=0;
  final MapController map=MapController();
  bool showAll=false;
  @override void dispose(){map.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    final selected=demonstrationRoutes[chosen];
    final visible=showAll?demonstrationRoutes:[selected];
    final assigned=widget.store.reports.where((r)=>r.collector==selected.brigade && r.status!='Solucionado').toList();
    return ListView(padding:const EdgeInsets.all(14),children:[
      Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF0E4945),Color(0xFF128D71)]),borderRadius:BorderRadius.circular(24)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(Icons.route,color:Colors.white,size:28),SizedBox(width:10),Expanded(child:Text('Rutas de recolección',style:TextStyle(fontSize:23,fontWeight:FontWeight.w900,color:Colors.white)))]),SizedBox(height:9),Text('Explora sectores, brigadas, horarios y paradas en un solo mapa.',style:TextStyle(color:Colors.white70)),SizedBox(height:12),Row(children:[Icon(Icons.local_shipping_outlined,color:Colors.white70,size:18),SizedBox(width:6),Text('3 brigadas',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w600)),SizedBox(width:20),Icon(Icons.place_outlined,color:Colors.white70,size:18),SizedBox(width:6),Text('24 paradas',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w600))])])),
      const SizedBox(height:8),
      const SizedBox(height:12),SizedBox(height:50,child:ListView(scrollDirection:Axis.horizontal,children:[for(int i=0;i<demonstrationRoutes.length;i++)Padding(padding:const EdgeInsets.only(right:7),child:ChoiceChip(avatar:CircleAvatar(radius:7,backgroundColor:demonstrationRoutes[i].color),label:Text(demonstrationRoutes[i].id),selected:chosen==i,onSelected:(_){setState(()=>chosen=i);map.move(demonstrationRoutes[i].waypoints[demonstrationRoutes[i].waypoints.length~/2],12.5);}))])),
      Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Container(width:6,height:44,decoration:BoxDecoration(color:selected.color,borderRadius:BorderRadius.circular(9))),const SizedBox(width:11),Expanded(child:Text(selected.name,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:19)))]),
        const SizedBox(height:9),_RouteDetail(Icons.local_shipping_outlined,selected.brigade),
        _RouteDetail(Icons.location_city,selected.zone),_RouteDetail(Icons.calendar_month,selected.days),
        _RouteDetail(Icons.schedule,selected.hours),
        _RouteDetail(Icons.pin_drop_outlined,'${selected.stops.length} paradas · ${assigned.length} reportes activos enlazados'),
      ]))),
      Row(children:[const Expanded(child:Text('Mapa del recorrido',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold))),const Text('Ver todas'),Switch(value:showAll,onChanged:(v)=>setState(()=>showAll=v))]),
      Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:(){final all=<LatLng>[for(final r in visible)...routeWithReports(r,widget.store.reports)];if(all.isNotEmpty)map.fitCamera(CameraFit.bounds(bounds:LatLngBounds.fromPoints(all),padding:const EdgeInsets.all(40)));},icon:const Icon(Icons.zoom_out_map),label:const Text('Ajustar recorrido'))),
      SizedBox(height:425,child:ClipRRect(borderRadius:BorderRadius.circular(18),child:FlutterMap(mapController:map,options:MapOptions(initialCenter:routeCenter(routeWithReports(selected,widget.store.reports)),initialZoom:11.5),children:[
        TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'com.unsaac.cusco_limpio_flutter'),
        PolylineLayer(polylines:[for(final route in visible)Polyline(points:routeWithReports(route,widget.store.reports),color:route.color,strokeWidth:5)]),
        MarkerLayer(markers:[for(final route in visible)for(int i=0;i<route.stops.length;i++)Marker(point:route.waypoints[((route.waypoints.length-1)*i/(route.stops.length-1)).round()],width:38,height:38,child:Tooltip(message:route.stops[i],child:CircleAvatar(backgroundColor:route.color,child:Text('${i+1}',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold))))),
          for(final r in assigned)Marker(point:r.location,width:26,height:26,child:GestureDetector(onTap:()=>_reportDetail(context,widget.store,r),child:Icon(Icons.report_problem,color:statusColor(r.status),size:25))) ]),
        const SimpleAttributionWidget(source:Text('© OpenStreetMap contributors')),
      ]))),
      const SizedBox(height:8),const Padding(padding:EdgeInsets.symmetric(horizontal:6),child:Text('Los reportes asignados están conectados al trazado de su brigada.',style:TextStyle(fontSize:12,color:_green,fontWeight:FontWeight.w600))),
      const SizedBox(height:12),Row(children:[const Icon(Icons.flag_circle_outlined,color:_green),const SizedBox(width:8),const Text('Paradas del recorrido',style:TextStyle(fontWeight:FontWeight.bold,fontSize:18))]),
      for(int i=0;i<selected.stops.length;i++)Card(child:ListTile(leading:CircleAvatar(backgroundColor:selected.color,child:Text('${i+1}',style:const TextStyle(color:Colors.white))),title:Text(selected.stops[i]),subtitle:Text('Parada de recorrido · ${selected.brigade}'))),
      const SizedBox(height:12),const Text('Incidencias asignadas a la brigada',style:TextStyle(fontWeight:FontWeight.bold,fontSize:18)),
      if(assigned.isEmpty)const Card(child:ListTile(title:Text('Sin reportes asignados'),subtitle:Text('Asigna incidencias desde el módulo de Gestión municipal.'))),
      for(final r in assigned)ReportCard(report:r,onTap:()=>_reportDetail(context,widget.store,r)),
      const SizedBox(height:10),Padding(padding:const EdgeInsets.symmetric(horizontal:4),child:Text('Recorridos de ejemplo · Las líneas unen puntos aproximados y no sustituyen indicaciones de tránsito.',style:const TextStyle(fontSize:11,color:Colors.black54))),
    ]);
  }
}
class _RouteDetail extends StatelessWidget {
  final IconData icon;final String text;
  const _RouteDetail(this.icon,this.text);
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Row(children:[Icon(icon,size:18,color:_green),const SizedBox(width:9),Expanded(child:Text(text))]));
}
