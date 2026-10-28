import 'auth.dart';
import 'dart:convert';
import 'dart:io';
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
  if (source.startsWith('file:')) {
    return Image.file(File(source.substring(5)), height:height, width:width, fit:fit,
      errorBuilder:(_,__,___)=>const Center(child:Icon(Icons.broken_image_outlined)));
  }
  return Image.asset('assets/images/$source.jpg',height:height,width:width,fit:fit);
}

class CleanReport {
  final String id, district, address, description, type, photo;
  String status, priority, collector;
  final double lat, lng;
  CleanReport({required this.id, required this.district, required this.address,
    required this.description, required this.type, required this.photo,
    required this.status, required this.priority, required this.collector,
    required this.lat, required this.lng});
  LatLng get location => LatLng(lat,lng);
  Map<String,dynamic> toJson() => {'id':id,'district':district,'address':address,
    'description':description,'type':type,'photo':photo,'status':status,
    'priority':priority,'collector':collector,'lat':lat,'lng':lng};
  factory CleanReport.fromJson(Map<String,dynamic> m) => CleanReport(
    id:m['id'] as String,district:m['district'] as String,address:m['address'] as String,
    description:m['description'] as String,type:m['type'] as String,photo:m['photo'] as String,
    status:m['status'] as String,priority:m['priority'] as String,
    collector:m['collector'] as String,lat:(m['lat'] as num).toDouble(),lng:(m['lng'] as num).toDouble());
}

List<CleanReport> demoReports() => [
  CleanReport(id:'CUS-00254', district:'Wanchaq', address:'Av. La Cultura', description:'Bolsas de residuos acumuladas junto a la vereda.',type:'Domésticos',photo:'domesticos',status:'Solucionado',priority:'Alta',collector:'Brigada 01',lat:-13.5218,lng:-71.9564),
  CleanReport(id:'CUS-00255', district:'Wanchaq', address:'Cerca del mercado Wanchaq',description:'Botellas y envolturas cerca de la zona comercial.',type:'Plásticos',photo:'plasticos',status:'En atención',priority:'Media',collector:'Brigada 02',lat:-13.529,lng:-71.959),
  CleanReport(id:'CUS-00256', district:'San Sebastián',address:'Plaza de San Sebastián',description:'Escombros sobre la vía pública.',type:'Escombros',photo:'escombros',status:'Pendiente',priority:'Alta',collector:'Sin asignar',lat:-13.5305,lng:-71.9362),
  CleanReport(id:'CUS-00257', district:'Cusco',address:'Av. El Sol',description:'Restos de alimentos cerca de contenedores.',type:'Orgánicos',photo:'domesticos',status:'En verificación',priority:'Baja',collector:'Brigada 03',lat:-13.5238,lng:-71.9752),
  CleanReport(id:'CUS-00258',district:'San Jerónimo',address:'Avenida principal de San Jerónimo',description:'Residuos dispersos al costado de la avenida.',type:'Domésticos',photo:'domesticos',status:'Pendiente',priority:'Media',collector:'Sin asignar',lat:-13.5473,lng:-71.8861),
  CleanReport(id:'CUS-00259',district:'Santiago',address:'Zona urbana de Santiago',description:'Botellas plásticas en la vía.',type:'Plásticos',photo:'plasticos',status:'En atención',priority:'Media',collector:'Brigada 01',lat:-13.5339,lng:-71.9874),
  CleanReport(id:'CUS-00260',district:'Cusco',address:'Centro Histórico de Cusco',description:'Acumulación de residuos domésticos.',type:'Domésticos',photo:'domesticos',status:'Pendiente',priority:'Alta',collector:'Sin asignar',lat:-13.5163,lng:-71.9781),
];

class DataStore extends ChangeNotifier {
  List<CleanReport> reports=demoReports();
  final Set<String> collected={};
  bool loaded=false;
  Future<void> load() async {
    try {
      final p=await SharedPreferences.getInstance();
      final raw=p.getString('cusco_limpio_reports_v1');
      if(raw!=null) reports=(jsonDecode(raw) as List).map((e)=>CleanReport.fromJson(Map<String,dynamic>.from(e as Map))).toList();
      collected.addAll(p.getStringList('cusco_limpio_collected_v1')??[]);
    } catch (_) { /* Demo remains usable if local storage is unavailable. */ }
    loaded=true;notifyListeners();
  }
  Future<void> save() async {
    notifyListeners();
    final p=await SharedPreferences.getInstance();
    await p.setString('cusco_limpio_reports_v1',jsonEncode(reports.map((e)=>e.toJson()).toList()));
    await p.setStringList('cusco_limpio_collected_v1',collected.toList());
  }
  Future<void> add(CleanReport r) async {reports.insert(0,r);await save();}
  Future<void> status(CleanReport r,String s) async {r.status=s;await save();}
  Future<void> assign(CleanReport r,String who) async {r.collector=who;await save();}
  Future<void> toggleCollected(String id) async {
    if(!collected.add(id)) collected.remove(id);
    await save();
  }
  Future<void> reset() async {reports=demoReports();collected.clear();await save();}
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
    theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:_green),scaffoldBackgroundColor:_background,
      appBarTheme:const AppBarTheme(backgroundColor:_background,foregroundColor:_dark,centerTitle:false),
      cardTheme:CardThemeData(color:Colors.white,elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18),side:const BorderSide(color:Color(0xFFE1EAE3))))),
    home:AnimatedBuilder(animation:auth,builder:(context,_) {
      if(!auth.ready)return const Scaffold(body:Center(child:CircularProgressIndicator()));
      return auth.current==null?EntryPage(auth:auth):AppShell(key:ValueKey(auth.current!.id),store:store,auth:auth);
    }));
}

enum UserRole {citizen,municipal,collector}
String roleName(UserRole role)=>switch(role){UserRole.citizen=>'Ciudadano',UserRole.municipal=>'Municipalidad',UserRole.collector=>'Recolector'};

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
    final role= user.role=='collector'?UserRole.collector:user.role=='citizen'?UserRole.citizen:UserRole.municipal;
    final labels=['Inicio','Mapa','Reportes',role==UserRole.collector?'Mis puntos':role==UserRole.citizen?'Mi cuenta':'Gestión'];
    final icons=[Icons.home_outlined,Icons.map_outlined,Icons.report_outlined,role==UserRole.collector?Icons.route:role==UserRole.citizen?Icons.person_outline:Icons.settings_outlined];
    final screens=<Widget>[
      HomeView(store:widget.store,role:role,onNavigate:(i)=>setState(()=>tab=i)),
      ReportsMapView(store:widget.store),
      ReportsView(store:widget.store,role:role),
      role==UserRole.collector?CollectorView(store:widget.store,brigade:user.brigade):
        role==UserRole.citizen?AccountView(user:user,auth:widget.auth,store:widget.store):ManagementView(store:widget.store,role:role),
    ];
    return Scaffold(
      appBar:AppBar(title:const Text('✳ Cusco Limpio',style:TextStyle(fontWeight:FontWeight.w800)),
        actions:[PopupMenuButton<String>(tooltip:'Sesión y cuenta',
          onSelected:(option){if(option=='logout')widget.auth.signOut();else setState(()=>tab=3);},
          itemBuilder:(_)=>[PopupMenuItem(value:'profile',child:Text(user.name)),const PopupMenuItem(value:'logout',child:Row(children:[Icon(Icons.logout),SizedBox(width:9),Text('Cerrar sesión')]))],
          child:Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:Chip(avatar:const Icon(Icons.verified_user_outlined,size:17),label:Text(user.role=='admin'?'Administrador':roleName(role)))))]),
      body:SafeArea(child:AnimatedBuilder(animation:widget.store,builder:(_,__)=>IndexedStack(index:tab,children:screens))),
      bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:[
        for(int i=0;i<4;i++)NavigationDestination(icon:Icon(icons[i]),label:labels[i]),
      ]),
    );
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
    Card(child:ListTile(leading:const Icon(Icons.assignment_outlined),title:const Text('Reportes en este teléfono'),subtitle:Text('${store.reports.length} reportes visibles en este prototipo'))),
    Card(child:ListTile(leading:const Icon(Icons.lock_outline),title:const Text('Privacidad de la demostración'),subtitle:const Text('Sesión local, sin cuentas remotas ni sincronización. No ingreses datos sensibles.'))),
    const SizedBox(height:17),OutlinedButton.icon(onPressed:auth.signOut,icon:const Icon(Icons.logout),label:const Text('Cerrar sesión')),
  ]);
}

class HomeView extends StatelessWidget {
  final DataStore store; final UserRole role; final ValueChanged<int> onNavigate;
  const HomeView({super.key,required this.store,required this.role,required this.onNavigate});
  @override Widget build(BuildContext context){
    final pending=store.reports.where((r)=>r.status!='Solucionado').length;
    return ListView(padding:const EdgeInsets.all(16),children:[
      Container(padding:const EdgeInsets.all(23),decoration:BoxDecoration(gradient:const LinearGradient(colors:[_dark,_green]),borderRadius:BorderRadius.circular(24)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.eco_outlined,color:Colors.white,size:40),const SizedBox(height:12),
          const Text('Una ciudad limpia empieza con todos',style:TextStyle(fontSize:26,fontWeight:FontWeight.w800,color:Colors.white)),
          const SizedBox(height:8),Text('Tu panel: ${roleName(role)}',style:const TextStyle(color:Colors.white70)),
          const SizedBox(height:15),FilledButton.icon(onPressed:()=>onNavigate(role==UserRole.collector?3:1),icon:const Icon(Icons.map),label:Text(role==UserRole.collector?'Ver puntos asignados':'Explorar mapa'))])),
      const SizedBox(height:15),Row(children:[Expanded(child:_Metric(label:'Reportes',value:'${store.reports.length}',icon:Icons.assignment_outlined)),const SizedBox(width:9),Expanded(child:_Metric(label:'Por atender',value:'$pending',icon:Icons.pending_actions_outlined)),const SizedBox(width:9),Expanded(child:_Metric(label:'Atendidos',value:'${store.collected.length}',icon:Icons.check_circle_outline))]),
      const SizedBox(height:20),const Text('¿Qué puedes hacer?',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800)),const SizedBox(height:8),
      if(role==UserRole.citizen)_InfoTile(icon:Icons.add_a_photo_outlined,title:'Reportar con fotografía',subtitle:'Toma una foto o elige una de la galería, marca la ubicación y envía el reporte.',onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ReportForm(store:store)))),
      _InfoTile(icon:Icons.place_outlined,title:'Ver puntos en Cusco',subtitle:'Reportes del prototipo y puntos demostrativos de recolección.',onTap:()=>onNavigate(1)),
      if(role==UserRole.collector)_InfoTile(icon:Icons.local_shipping_outlined,title:'Seguimiento del recolector',subtitle:'Consulta puntos asignados y márcalos como atendidos.',onTap:()=>onNavigate(3)),
      const SizedBox(height:10),const _DemoNotice(),
    ]);
  }
}
class _Metric extends StatelessWidget {final String label,value;final IconData icon; const _Metric({required this.label,required this.value,required this.icon});
  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[Icon(icon,color:_green),const SizedBox(height:6),Text(value,style:const TextStyle(fontSize:23,fontWeight:FontWeight.bold)),Text(label,textAlign:TextAlign.center,style:const TextStyle(fontSize:11))])));}
class _InfoTile extends StatelessWidget {final IconData icon;final String title,subtitle;final VoidCallback onTap;
  const _InfoTile({required this.icon,required this.title,required this.subtitle,required this.onTap});
  @override Widget build(BuildContext context)=>Card(child:ListTile(onTap:onTap,leading:CircleAvatar(backgroundColor:const Color(0xFFE6F3EC),child:Icon(icon,color:_green)),title:Text(title,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text(subtitle),trailing:const Icon(Icons.chevron_right)));}
class _DemoNotice extends StatelessWidget {const _DemoNotice();@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFFFFF4DE),borderRadius:BorderRadius.circular(12)),child:const Text('PROTOTIPO ACADÉMICO · Los puntos iniciales provienen de reportes ficticios del prototipo web. No representan rutas, horarios ni paraderos oficiales de recolección municipal.',style:TextStyle(fontSize:12,color:Color(0xFF795414))));}

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

class ReportsView extends StatefulWidget {final DataStore store;final UserRole role;const ReportsView({super.key,required this.store,required this.role});@override State<ReportsView> createState()=>_ReportsViewState();}
class _ReportsViewState extends State<ReportsView> {
  String filter='Todos';
  @override Widget build(BuildContext context){final records=widget.store.reports.where((r)=>filter=='Todos'||r.status==filter).toList();
    return Scaffold(body:Column(children:[Padding(padding:const EdgeInsets.all(14),child:Row(children:[const Expanded(child:Text('Reportes ciudadanos',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800))),if(widget.role==UserRole.citizen)FilledButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ReportForm(store:widget.store))),icon:const Icon(Icons.add),label:const Text('Nuevo'))])),
      SizedBox(height:46,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:12),children:[for(final s in ['Todos','Pendiente','En verificación','En atención','Solucionado'])Padding(padding:const EdgeInsets.only(right:6),child:ChoiceChip(label:Text(s),selected:filter==s,onSelected:(_)=>setState(()=>filter=s)))])),
      Expanded(child:ListView.builder(padding:const EdgeInsets.all(12),itemCount:records.length,itemBuilder:(_,i)=>ReportCard(report:records[i],onTap:()=>_reportDetail(context,widget.store,records[i]))))]));
  }
}
class ReportCard extends StatelessWidget {final CleanReport report;final VoidCallback onTap;const ReportCard({super.key,required this.report,required this.onTap});
  @override Widget build(BuildContext context)=>Card(child:InkWell(borderRadius:BorderRadius.circular(18),onTap:onTap,child:Padding(padding:const EdgeInsets.all(12),child:Row(children:[ClipRRect(borderRadius:BorderRadius.circular(10),child:reportPhoto(report.photo,width:83,height:90)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(report.id,style:const TextStyle(fontWeight:FontWeight.bold)),Text(report.address,maxLines:2,overflow:TextOverflow.ellipsis),Text('${report.district} · ${report.type}',style:const TextStyle(fontSize:12,color:Colors.black54)),const SizedBox(height:5),Text(report.status,style:TextStyle(color:statusColor(report.status),fontWeight:FontWeight.bold))])),const Icon(Icons.chevron_right)]))));
}
void _reportDetail(BuildContext context,DataStore store,CleanReport r){showModalBottomSheet(context:context,isScrollControlled:true,showDragHandle:true,builder:(_)=>SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(20,0,20,24),child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${r.id} · ${r.status}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:19)),const SizedBox(height:10),Text(r.address,style:const TextStyle(fontWeight:FontWeight.w700)),Text('${r.district} · ${r.type}'),const SizedBox(height:10),Text(r.description),const SizedBox(height:8),Text('Prioridad: ${r.priority} · Personal: ${r.collector}'),Text('Coordenadas: ${r.lat}, ${r.lng}'),const SizedBox(height:12),ClipRRect(borderRadius:BorderRadius.circular(12),child:reportPhoto(r.photo,height:180,width:double.infinity)),const SizedBox(height:6),Text(r.photo.startsWith('file:')?'Fotografía adjuntada desde el dispositivo.':'Imagen ilustrativa del prototipo.',style:const TextStyle(fontSize:11,color:Colors.black54))])))));}

class ReportForm extends StatefulWidget {final DataStore store;const ReportForm({super.key,required this.store});@override State<ReportForm> createState()=>_ReportFormState();}
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
      final directory=await getApplicationDocumentsDirectory();
      final photoDir=Directory('${directory.path}/fotos_reportes');
      await photoDir.create(recursive:true);
      final file=await File(captured!.path).copy('${photoDir.path}/reporte_${DateTime.now().microsecondsSinceEpoch}.jpg');
      final r=CleanReport(id:'CUS-${DateTime.now().millisecondsSinceEpoch}',
        district:district,address:address.text.trim(),description:desc.text.trim(),
        type:type,photo:'file:${file.path}',status:'Pendiente',priority:'Media',
        collector:'Sin asignar',lat:picked!.latitude,lng:picked!.longitude);
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
        child:Image.file(File(captured!.path),height:185,fit:BoxFit.cover))
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
      const Text('Demostración local: la foto y el reporte se guardan en este teléfono; '
        'aún no se sincronizan con otros usuarios.',style:TextStyle(fontSize:12,color:Colors.black54)),
    ])));
}

class ManagementView extends StatelessWidget {final DataStore store;final UserRole role;const ManagementView({super.key,required this.store,required this.role});
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(14),children:[const Text('Gestión de incidencias',style:TextStyle(fontWeight:FontWeight.w800,fontSize:21)),const _DemoNotice(),const SizedBox(height:10),if(role==UserRole.citizen)const Card(child:Padding(padding:EdgeInsets.all(16),child:Text('Cambia al perfil Municipalidad desde la parte superior para asignar brigadas y actualizar estados.'))),
    for(final r in store.reports)Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${r.id} · ${r.address}',style:const TextStyle(fontWeight:FontWeight.bold)),Text('Estado: ${r.status} · ${r.district}'),const SizedBox(height:9),
      DropdownButtonFormField<String>(initialValue:r.collector,decoration:const InputDecoration(labelText:'Brigada asignada',border:OutlineInputBorder()),items:['Sin asignar','Brigada 01','Brigada 02','Brigada 03'].map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),onChanged:role==UserRole.municipal?(s){if(s!=null)store.assign(r,s);}:null),const SizedBox(height:9),
      DropdownButtonFormField<String>(initialValue:r.status,decoration:const InputDecoration(labelText:'Estado del reporte',border:OutlineInputBorder()),items:['Pendiente','En verificación','En atención','Solucionado'].map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),onChanged:role==UserRole.municipal?(s){if(s!=null)store.status(r,s);}:null),
    ]))),const SizedBox(height:15),OutlinedButton.icon(onPressed:role==UserRole.municipal?()=>_confirmReset(context,store):null,icon:const Icon(Icons.restart_alt),label:const Text('Restaurar demostración'))]);
}
void _confirmReset(BuildContext context,DataStore store) async {final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Restablecer datos'),content:const Text('Se perderán los cambios locales de esta demostración.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Restablecer'))]));if(yes==true)await store.reset();}

class CollectorView extends StatefulWidget {final DataStore store;final String brigade;const CollectorView({super.key,required this.store,required this.brigade});@override State<CollectorView> createState()=>_CollectorViewState();}
class _CollectorViewState extends State<CollectorView> {
  late String selected;final controller=MapController();
  @override void initState(){super.initState();selected=widget.brigade.isEmpty?'Brigada 01':widget.brigade;}
  @override void dispose(){controller.dispose();super.dispose();}
  LatLng? me;bool busy=false;
  List<CleanReport> get assigned=>widget.store.reports.where((r)=>r.collector==selected && r.status!='Solucionado').toList();
  Future<void> locate() async {setState(()=>busy=true);final p=await askLocation(context);if(!mounted)return;setState((){busy=false;if(p!=null)me=LatLng(p.latitude,p.longitude);});if(me!=null)controller.move(me!,15);}
  @override Widget build(BuildContext context){final points=assigned;final remaining=points.where((r)=>!widget.store.collected.contains(r.id)).toList();
    return ListView(padding:const EdgeInsets.all(14),children:[const Text('Recolector · puntos asignados',style:TextStyle(fontSize:21,fontWeight:FontWeight.w800)),const SizedBox(height:5),const _DemoNotice(),const SizedBox(height:12),
      Card(child:ListTile(leading:const Icon(Icons.local_shipping),title:Text('Mi brigada: $selected'),subtitle:const Text('Asignada al usuario de demostración'))),const SizedBox(height:12),
      Card(child:Padding(padding:const EdgeInsets.all(15),child:Row(children:[const Icon(Icons.route,color:_green,size:32),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${points.length} puntos asignados',style:const TextStyle(fontWeight:FontWeight.bold)),Text('${remaining.length} pendientes de atención')]))]))),const SizedBox(height:10),
      SizedBox(height:315,child:ClipRRect(borderRadius:BorderRadius.circular(17),child:FlutterMap(mapController:controller,options:const MapOptions(initialCenter:_center,initialZoom:11.8),children:[
        TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'com.unsaac.cusco_limpio_flutter'),
        if(points.length>1)PolylineLayer(polylines:[Polyline(points:points.map((e)=>e.location).toList(),strokeWidth:4,color:_green)]),
        MarkerLayer(markers:[for(int i=0;i<points.length;i++)Marker(point:points[i].location,width:44,height:44,child:GestureDetector(onTap:()=>_reportDetail(context,widget.store,points[i]),child:CircleAvatar(backgroundColor:widget.store.collected.contains(points[i].id)?Colors.grey:_green,child:Text('${i+1}',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold))))),if(me!=null)Marker(point:me!,child:const Icon(Icons.my_location,color:Colors.blue,size:35))]),
        const SimpleAttributionWidget(source:Text('© OpenStreetMap contributors')),
      ]))),
      Padding(padding:const EdgeInsets.symmetric(vertical:6),child:Row(children:[Expanded(child:OutlinedButton.icon(onPressed:busy?null:locate,icon:const Icon(Icons.my_location),label:Text(busy?'Localizando...':'Mi ubicación'))),const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:()=>controller.move(_center,12),icon:const Icon(Icons.center_focus_strong),label:const Text('Ver zona')))])),
      const Text('Puntos para atender',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
      if(points.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(20),child:Text('Esta brigada no tiene reportes activos asignados. Cambia de brigada o asigna reportes desde Municipalidad.'))),
      for(int i=0;i<points.length;i++)Card(child:CheckboxListTile(value:widget.store.collected.contains(points[i].id),onChanged:(_)=>widget.store.toggleCollected(points[i].id),secondary:CircleAvatar(child:Text('${i+1}')),title:Text(points[i].address),subtitle:Text('${points[i].district} · ${points[i].id} · ${points[i].status}\nToca para marcar atención demostrativa'),isThreeLine:true)),
      const SizedBox(height:8),const Text('La línea une puntos en orden de lista: NO calcula vías transitables ni representa la ruta oficial del camión. La ubicación del recolector aparece solamente cuando usa «Mi ubicación»; no existe rastreo remoto en vivo.',style:TextStyle(fontSize:12,color:Colors.black54)),
    ]);
  }
}
