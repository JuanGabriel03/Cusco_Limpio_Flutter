import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// AUTENTICACION LOCAL DE DEMOSTRACION. NO APROPIADA PARA PRODUCCION.
// Para desplegar con usuarios reales se necesita backend y autorizacion del servidor.
class DemoUser {
  final String id, name, email, role, brigade, salt, passwordHash;
  const DemoUser({required this.id, required this.name, required this.email,
    required this.role, required this.brigade, required this.salt, required this.passwordHash});
  factory DemoUser.fromJson(Map<String,dynamic> json) => DemoUser(
    id: json['id'] as String, name: json['name'] as String,
    email: json['email'] as String,role: json['role'] as String,
    brigade: json['brigade'] as String? ?? '',salt: json['salt'] as String,
    passwordHash: json['passwordHash'] as String);
  Map<String,dynamic> toJson()=>{'id':id,'name':name,'email':email,'role':role,
    'brigade':brigade,'salt':salt,'passwordHash':passwordHash};
}

class DemoAuth extends ChangeNotifier {
  static const _usersKey = 'cusco_limpio_demo_users_v2';
  static const _sessionKey = 'cusco_limpio_demo_session_v2';
  final List<DemoUser> _users = [];
  DemoUser? current;
  bool ready = false;
  static String _salt() {
    final random=Random.secure();
    return List.generate(24,(_)=>random.nextInt(256).toRadixString(16).padLeft(2,'0')).join();
  }
  static String _hash(String password,String salt)=>sha256.convert(utf8.encode('$salt:$password')).toString();
  DemoUser _make(String name,String email,String role,String brigade,String password){
    final salt=_salt();
    return DemoUser(id:'u-${DateTime.now().microsecondsSinceEpoch}-${_users.length}',name:name,email:email.toLowerCase(),role:role,brigade:brigade,salt:salt,passwordHash:_hash(password,salt));
  }
  Future<void> initialize() async {
    try {
      final prefs=await SharedPreferences.getInstance();
      final data=prefs.getString(_usersKey);
      if(data!=null) {
        for(final item in jsonDecode(data) as List) {
          _users.add(DemoUser.fromJson(Map<String,dynamic>.from(item as Map)));
        }
      } else {
        // Accesos solo para demostracion; no deben publicarse en una app real.
        _users.addAll([
          _make('Ana Ciudadana','ana@demo.pe','citizen','','Demo2026!'),
          _make('Coordinación municipal','municipal@demo.pe','municipal','','Demo2026!'),
          _make('Recolector brigada 01','recolector@demo.pe','collector','Brigada 01','Demo2026!'),
          _make('Administración Cusco Limpio','admin@demo.pe','admin','','Demo2026!'),
        ]);
        await _persistUsers();
      }
      final id=prefs.getString(_sessionKey);
      for(final user in _users) {if(user.id==id) current=user;}
    } catch (_) { // Permite arrancar la interfaz aunque falle el almacenamiento local.
    } finally {ready=true;notifyListeners();}
  }
  Future<void> _persistUsers() async {
    final prefs=await SharedPreferences.getInstance();
    await prefs.setString(_usersKey,jsonEncode(_users.map((u)=>u.toJson()).toList()));
  }
  Future<String?> signIn(String email,String password) async {
    final clean=email.trim().toLowerCase();
    DemoUser? found;
    for(final u in _users) {if(u.email==clean){found=u;break;}}
    if(found==null || found.passwordHash!=_hash(password,found.salt)) return 'Correo o contraseña incorrectos.';
    current=found;
    final prefs=await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey,found.id);
    notifyListeners(); return null;
  }
  Future<String?> signUp(String name,String email,String password) async {
    final clean=email.trim().toLowerCase();
    if(_users.any((u)=>u.email==clean))return 'Ese correo ya fue registrado en este dispositivo.';
    final newUser=_make(name.trim(),clean,'citizen','',password);
    _users.add(newUser);
    await _persistUsers();
    current=newUser;
    final prefs=await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey,newUser.id);
    notifyListeners(); return null;
  }
  Future<void> signOut() async {
    current=null;
    final prefs=await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    notifyListeners();
  }
}

class EntryPage extends StatefulWidget {
  final DemoAuth auth;
  const EntryPage({super.key,required this.auth});
  @override State<EntryPage> createState()=>_EntryPageState();
}
class _EntryPageState extends State<EntryPage> {
  final keyForm=GlobalKey<FormState>();
  final name=TextEditingController(), email=TextEditingController(), password=TextEditingController();
  bool register=false,hidden=true,busy=false;
  @override void dispose(){name.dispose();email.dispose();password.dispose();super.dispose();}
  Future<void> submit() async {
    if(!keyForm.currentState!.validate())return;
    setState(()=>busy=true);
    try {
      final result=register
        ? await widget.auth.signUp(name.text,email.text,password.text)
        : await widget.auth.signIn(email.text,password.text);
      if(mounted && result!=null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(result)));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('No se pudo completar la operación: $e')));}
    if(mounted)setState(()=>busy=false);
  }
  void demo(String value){email.text=value;password.text='Demo2026!';setState(()=>register=false);}
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor:const Color(0xFFF4F8F5),
    body: SafeArea(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:470),
      child:ListView(padding:const EdgeInsets.all(24),children:[
        const SizedBox(height:15),
        Container(padding:const EdgeInsets.all(24),decoration:BoxDecoration(
          gradient:const LinearGradient(colors:[Color(0xFF103D32),Color(0xFF217E60)]),borderRadius:BorderRadius.circular(26)),
          child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(Icons.eco,color:Colors.white,size:48),SizedBox(height:10),
            Text('Cusco Limpio',style:TextStyle(color:Colors.white,fontSize:30,fontWeight:FontWeight.w800)),
            SizedBox(height:5),Text('Reporta, organiza y atiende los residuos de la ciudad.',style:TextStyle(color:Colors.white70))])),
        const SizedBox(height:22),
        Text(register?'Crear cuenta ciudadana':'Bienvenido de nuevo',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:24)),
        const SizedBox(height:5),Text(register?'Regístrate para reportar y seguir incidencias.':'Ingresa para continuar a tu panel.',style:const TextStyle(color:Colors.black54)),
        const SizedBox(height:18),
        Form(key:keyForm,child:Column(children:[
          if(register)...[TextFormField(controller:name,textCapitalization:TextCapitalization.words,decoration:const InputDecoration(labelText:'Nombre completo',prefixIcon:Icon(Icons.person_outline),border:OutlineInputBorder()),validator:(v)=>(v?.trim().length??0)<3?'Escribe tu nombre completo':null),const SizedBox(height:12)],
          TextFormField(controller:email,keyboardType:TextInputType.emailAddress,autofillHints:const [AutofillHints.email],decoration:const InputDecoration(labelText:'Correo electrónico',prefixIcon:Icon(Icons.email_outlined),border:OutlineInputBorder()),validator:(v)=>!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v?.trim()??'')?'Introduce un correo válido':null),
          const SizedBox(height:12),
          TextFormField(controller:password,obscureText:hidden,decoration:InputDecoration(labelText:'Contraseña',prefixIcon:const Icon(Icons.lock_outline),border:const OutlineInputBorder(),suffixIcon:IconButton(tooltip:'Mostrar contraseña',onPressed:()=>setState(()=>hidden=!hidden),icon:Icon(hidden?Icons.visibility:Icons.visibility_off))),validator:(v)=>(v?.length??0)<8?'Usa al menos 8 caracteres':null),
          const SizedBox(height:16),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:busy?null:submit,icon:Icon(register?Icons.person_add_alt_1:Icons.login),label:Padding(padding:const EdgeInsets.all(12),child:Text(register?'Registrarme':'Iniciar sesión')))),
          TextButton(onPressed:busy?null:()=>setState(()=>register=!register),child:Text(register?'Ya tengo cuenta':'Crear cuenta ciudadana')),
        ])),
        const Divider(height:34),
        const Text('Accesos para probar los perfiles',style:TextStyle(fontWeight:FontWeight.bold)),
        const SizedBox(height:8),
        Wrap(spacing:7,runSpacing:6,children:[
          ActionChip(avatar:const Icon(Icons.person_outline,size:18),label:const Text('Ciudadano'),onPressed:()=>demo('ana@demo.pe')),
          ActionChip(avatar:const Icon(Icons.local_shipping_outlined,size:18),label:const Text('Recolector'),onPressed:()=>demo('recolector@demo.pe')),
          ActionChip(avatar:const Icon(Icons.account_balance_outlined,size:18),label:const Text('Municipalidad'),onPressed:()=>demo('municipal@demo.pe')),
          ActionChip(avatar:const Icon(Icons.admin_panel_settings_outlined,size:18),label:const Text('Administrador'),onPressed:()=>demo('admin@demo.pe')),
        ]),
        const SizedBox(height:12),
        const Text('DEMO LOCAL · Contraseña de pruebas: Demo2026! · No uses contraseñas reales. Los datos no se comparten entre teléfonos. Los cargos de personal se habilitarán desde un servidor en la versión de producción.',style:TextStyle(fontSize:12,color:Color(0xFF79612D))),
      ])))),
  );
}
