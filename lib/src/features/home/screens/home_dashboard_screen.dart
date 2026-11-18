import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openlock/src/core/router/app_router.dart';
import 'package:openlock/src/core/interfaces/enforcement_bridge.dart';
import 'package:openlock/src/features/apps/providers/apps_providers.dart';
import 'package:openlock/src/features/enforcement/models/lock_config.dart';
import 'package:openlock/src/features/enforcement/providers/config_providers.dart';
import 'package:openlock/src/features/intruder/providers/intruder_providers.dart';

class _HomePalette {
 static Color bg=Color(0xFF0C0D14), panel=const Color(0xFF171927), high=const Color(0xFF292D43);
 static Color ink=const Color(0xFFF1F0F7), muted=const Color(0xFF9D9BB3), amber=const Color(0xFFFF9E42), amber2=const Color(0xFFFFB259), indigo=const Color(0xFF8B5CF6);
 static void apply(bool dark) {
  bg=dark?const Color(0xFF0C0D14):const Color(0xFFF5F7FA);
  panel=dark?const Color(0xFF171927):const Color(0xFFFFFFFF);
  high=dark?const Color(0xFF292D43):const Color(0xFFE8EDF4);
  ink=dark?const Color(0xFFF1F0F7):const Color(0xFF202938);
  muted=dark?const Color(0xFF9D9BB3):const Color(0xFF687386);
  amber=dark?const Color(0xFFFF9E42):const Color(0xFFB96B20);
  amber2=dark?const Color(0xFFFFB259):const Color(0xFF9D5817);
  indigo=dark?const Color(0xFF8B5CF6):const Color(0xFF7054C8);
 }
}
Color get _bg=>_HomePalette.bg; Color get _panel=>_HomePalette.panel; Color get _high=>_HomePalette.high;
Color get _ink=>_HomePalette.ink; Color get _muted=>_HomePalette.muted; Color get _amber=>_HomePalette.amber; Color get _amber2=>_HomePalette.amber2; Color get _indigo=>_HomePalette.indigo;

class HomeDashboardScreen extends ConsumerStatefulWidget {
 const HomeDashboardScreen({super.key});
 @override ConsumerState<HomeDashboardScreen> createState()=>_HomeDashboardScreenState();
}
class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen>{
 Timer? _timer; DateTime _now=DateTime.now();
 @override void initState(){super.initState();_timer=Timer.periodic(const Duration(seconds:1),(_){if(mounted)setState(()=>_now=DateTime.now());});}
 @override void dispose(){_timer?.cancel();super.dispose();}
 @override Widget build(BuildContext context){
  final isDark=Theme.of(context).brightness==Brightness.dark;\n  _HomePalette.apply(isDark);\n  final config=ref.watch(configControllerProvider).valueOrNull??LockConfig.empty;
  final apps=ref.watch(installedAppsProvider).valueOrNull??const [];
  final events=ref.watch(intruderControllerProvider).valueOrNull??const [];
  final schedules=config.schedules.where((s)=>s.enabled).toList();
  final locked=apps.where((a)=>config.lockedPackages.contains(a.packageName)).toList();
  final active=config.strictModeActiveAt(_now), end=config.strictModeEndsAtMillis;
  final left=active&&end!=null?math.max(0,((end-_now.millisecondsSinceEpoch)/1000).floor()):0;
  final timer=end==null?'∞':_fmtDuration(left);
  return Scaffold(backgroundColor:_bg,body:SafeArea(bottom:false,child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:560),child:ListView(padding:const EdgeInsets.fromLTRB(18,16,18,28),children:[
   Row(children:[Container(width:48,height:48,decoration:BoxDecoration(borderRadius:BorderRadius.circular(15),gradient:const LinearGradient(colors:[Color(0xFF393047),_high]),border:Border.all(color:Colors.white12)),child:const Icon(Icons.shield_rounded,color:_amber,size:27)),const SizedBox(width:13),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('OpenLock',style:TextStyle(color:_ink,fontSize:22,fontWeight:FontWeight.w800)),SizedBox(height:2),Text('AURA SENTINEL V2.4',style:TextStyle(color:_amber,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1.2))])),Material(color:Colors.transparent,child:InkWell(onTap:()=>context.go(AppRoutes.settings),borderRadius:BorderRadius.circular(14),child:Container(width:42,height:42,decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(14),border:Border.all(color:Colors.white12)),child:const Icon(Icons.person_outline_rounded,color:_muted,size:21))))]),
   const SizedBox(height:22),
   _Pill(message:events.isEmpty?'OpenLock siap menjaga fokusmu':_clock(events.first.timestamp)+' WIB • Percobaan akses tercatat'),
   const SizedBox(height:18),
   _Hero(active:active,timer:active?timer:'--:--:--',target:end==null?null:DateTime.fromMillisecondsSinceEpoch(end),onTap:()=>context.push(AppRoutes.strictMode)),
   const SizedBox(height:16),
   Row(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Expanded(flex:3,child:_Bento(title:'STATUS KUBAH',icon:Icons.verified_user_rounded,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(events.length.toString()+' BLOKIR',style:const TextStyle(color:_ink,fontSize:28,fontWeight:FontWeight.w800)),const Text('Percobaan aplikasi ditangkal',style:TextStyle(color:_muted,fontSize:11)),const SizedBox(height:14),const _Sparkline()]))),
    const SizedBox(width:10),
    Expanded(flex:2,child:Column(children:[Expanded(child:_Mini(title:'TERKUNCI',icon:Icons.lock_rounded,value:config.lockedPackages.length.toString(),suffix:'Aplikasi',tint:_amber2)),const SizedBox(height:10),Expanded(child:_Mini(title:'JADWAL',icon:Icons.alarm_on_rounded,value:schedules.length.toString(),suffix:'Aktif',tint:_indigo))])),
   ]),
   const SizedBox(height:16),
   _ScheduleCard(name:schedules.isEmpty?'Jadwal Jam Kerja Produktif':schedules.first.name,detail:schedules.isEmpty?'Belum ada rutinitas terjadwal':_days(schedules.first.weekdays),time:schedules.isEmpty?'—':_minute(schedules.first.startMinutes)+' – '+_minute(schedules.first.endMinutes),onTap:()=>context.go(AppRoutes.schedules)),
   const SizedBox(height:16),
   Row(children:[const Expanded(child:Text('Aplikasi Dibatasi',style:TextStyle(color:_ink,fontSize:16,fontWeight:FontWeight.w700))),TextButton(onPressed:()=>context.go(AppRoutes.apps),child:const Text('SESUAIKAN',style:TextStyle(color:_amber2,fontSize:10,fontWeight:FontWeight.w800)))]),
   if(locked.isEmpty)const _EmptyApps() else GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:math.min(locked.length,4),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,mainAxisSpacing:10,crossAxisSpacing:10,mainAxisExtent:68),itemBuilder:(_,i)=>_AppTile(app:locked[i])),
   const SizedBox(height:16),
   Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(17),border:Border.all(color:_amber.withValues(alpha:.15))),child:const Row(children:[Icon(Icons.psychology_rounded,color:_amber2,size:22),SizedBox(width:11),Expanded(child:Text('“Disiplin adalah memilih antara apa yang kamu inginkan sekarang dan apa yang paling kamu inginkan nanti.”',style:TextStyle(color:_muted,fontSize:11,height:1.45,fontStyle:FontStyle.italic)))])),
  ])))));
 }
}
class _Pill extends StatelessWidget{const _Pill({required this.message});final String message;@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.symmetric(horizontal:13,vertical:11),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(30),border:Border.all(color:Colors.white10)),child:Row(children:[Container(width:8,height:8,decoration:const BoxDecoration(color:_amber,shape:BoxShape.circle)),const SizedBox(width:9),Expanded(child:Text(message,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:_muted,fontSize:10,fontFamily:'monospace'))),const SizedBox(width:6),Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:_amber.withValues(alpha:.1),borderRadius:BorderRadius.circular(20),border:Border.all(color:_amber.withValues(alpha:.3))),child:const Row(children:[Icon(Icons.verified_rounded,color:_amber,size:12),SizedBox(width:4),Text('AMAN',style:TextStyle(color:_amber2,fontSize:9,fontWeight:FontWeight.w800))]))]));}
class _Hero extends StatelessWidget{const _Hero({required this.active,required this.timer,required this.target,required this.onTap});final bool active;final String timer;final DateTime? target;final VoidCallback onTap;@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.fromLTRB(18,18,18,17),decoration:BoxDecoration(borderRadius:BorderRadius.circular(30),gradient:const RadialGradient(center:Alignment(0,-.65),radius:1.35,colors:[Color(0xFF30263D),Color(0xFF171927),_bg]),border:Border.all(color:Colors.white12),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.35),blurRadius:28,offset:const Offset(0,12)),BoxShadow(color:_amber.withValues(alpha:.045),blurRadius:38,offset:const Offset(-35,-24)),BoxShadow(color:_indigo.withValues(alpha:.10),blurRadius:42,offset:const Offset(35,35))]),child:Column(children:[
 SizedBox(width:264,height:264,child:Stack(alignment:Alignment.center,children:[CustomPaint(size:const Size(238,238),painter:_Dial(active)),Column(mainAxisSize:MainAxisSize.min,children:[
 Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),decoration:BoxDecoration(color:_amber.withValues(alpha:.13),borderRadius:BorderRadius.circular(24),border:Border.all(color:_amber.withValues(alpha:.35))),child:Text(active?'MODE KETAT AKTIF':'MODE KETAT NONAKTIF',style:const TextStyle(color:_amber2,fontSize:9,fontWeight:FontWeight.w800,letterSpacing:1.1))),
 const SizedBox(height:12),const Text('SISA WAKTU TERKUNCI',style:TextStyle(color:_muted,fontSize:10,letterSpacing:1.8,fontFamily:'monospace')),const SizedBox(height:4),Text(timer,style:const TextStyle(color:_ink,fontSize:34,fontWeight:FontWeight.w800,letterSpacing:-1)),const SizedBox(height:7),
 Text(target==null?'Target: Tanpa batas waktu':'Target: '+_clock(target!)+' WIB',style:const TextStyle(color:_muted,fontSize:10,fontFamily:'monospace'))
 ])])),
 const SizedBox(height:8),Material(color:Colors.transparent,child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(19),child:Ink(padding:const EdgeInsets.symmetric(horizontal:14,vertical:13),decoration:BoxDecoration(gradient:const LinearGradient(colors:[_high,Color(0xFF38304F)]),borderRadius:BorderRadius.circular(19),border:Border.all(color:Colors.white12)),child:const Row(children:[Icon(Icons.lock_clock_rounded,color:_amber2,size:24),SizedBox(width:11),Expanded(child:Text('KELOLA MODE KETAT',style:TextStyle(color:_ink,fontSize:11,fontWeight:FontWeight.w800,letterSpacing:1.1))),Icon(Icons.tune_rounded,color:_amber,size:20)]))))]));}
class _Dial extends CustomPainter {
 const _Dial(this.active);
 final bool active;
 @override void paint(Canvas canvas, Size size) {
  final center=Offset(size.width/2,size.height/2), radius=size.width*.367;
  final rect=Rect.fromCircle(center:center,radius:radius);
  // Faint outer halo and dotted technical orbit.
  canvas.drawCircle(center,radius+17,Paint()..style=PaintingStyle.stroke..strokeWidth=1..color=Colors.white.withValues(alpha:.035));
  final orbit=Paint()..style=PaintingStyle.stroke..strokeWidth=1..color=const Color(0xFF777B9A).withValues(alpha:.22);
  for(var i=0;i<72;i++){
   final a=-math.pi/2+i*math.pi*2/72;
   final p1=Offset(center.dx+math.cos(a)*(radius+10),center.dy+math.sin(a)*(radius+10));
   final p2=Offset(center.dx+math.cos(a)*(radius+12),center.dy+math.sin(a)*(radius+12));
   canvas.drawLine(p1,p2,orbit);
  }
  canvas.drawCircle(center,radius,Paint()..style=PaintingStyle.stroke..strokeWidth=11..strokeCap=StrokeCap.round..color=const Color(0xFF1C1F30));
  canvas.drawCircle(center,radius,Paint()..style=PaintingStyle.stroke..strokeWidth=1..color=Colors.white.withValues(alpha:.055));
  if(!active)return;
  final gradient=const SweepGradient(startAngle:-math.pi/2,endAngle:math.pi*1.5,colors:[_amber2,Color(0xFFFF7B39),_indigo,Color(0xFF6366F1)]);
  final shader=gradient.createShader(rect);
  final sweep=math.pi*1.42;
  // Two blurred passes create the amber/violet ambient glow from Stitch.
  canvas.drawArc(rect,-math.pi/2,sweep,false,Paint()..style=PaintingStyle.stroke..strokeWidth=22..strokeCap=StrokeCap.round..shader=shader..maskFilter=const MaskFilter.blur(BlurStyle.normal,13));
  canvas.drawArc(rect,-math.pi/2,sweep,false,Paint()..style=PaintingStyle.stroke..strokeWidth=14..strokeCap=StrokeCap.round..shader=shader..maskFilter=const MaskFilter.blur(BlurStyle.normal,3));
  canvas.drawArc(rect,-math.pi/2,sweep,false,Paint()..style=PaintingStyle.stroke..strokeWidth=11..strokeCap=StrokeCap.round..shader=shader);
  final satellite=Offset(center.dx,center.dy-radius);
  canvas.drawCircle(satellite,8,Paint()..color=_amber.withValues(alpha:.18)..maskFilter=const MaskFilter.blur(BlurStyle.normal,7));
  canvas.drawCircle(satellite,4.5,Paint()..color=_amber2);
  canvas.drawCircle(satellite,2,Paint()..color=Colors.white);
 }
 @override bool shouldRepaint(covariant _Dial old)=>old.active!=active;
}
class _Bento extends StatelessWidget{const _Bento({required this.title,required this.icon,required this.child});final String title;final IconData icon;final Widget child;@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(21),border:Border.all(color:Colors.white10)),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(title,style:const TextStyle(color:_muted,fontSize:10,letterSpacing:1,fontWeight:FontWeight.w700))),Icon(icon,color:_amber,size:18)]),const SizedBox(height:18),child]));}
class _Mini extends StatelessWidget{const _Mini({required this.title,required this.icon,required this.value,required this.suffix,required this.tint});final String title,value,suffix;final IconData icon;final Color tint;@override Widget build(BuildContext c)=>Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(19),border:Border.all(color:Colors.white10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Row(children:[Expanded(child:Text(title,style:const TextStyle(color:_muted,fontSize:9,fontWeight:FontWeight.w700,letterSpacing:.6))),Icon(icon,color:tint,size:16)]),Row(crossAxisAlignment:CrossAxisAlignment.baseline,textBaseline:TextBaseline.alphabetic,children:[Text(value,style:const TextStyle(color:_ink,fontSize:21,fontWeight:FontWeight.w800)),const SizedBox(width:5),Flexible(child:Text(suffix,style:TextStyle(color:tint,fontSize:9)))])]));}
class _Sparkline extends StatelessWidget{const _Sparkline();@override Widget build(BuildContext c)=>SizedBox(height:28,child:CustomPaint(painter:_Spark()));}
class _Spark extends CustomPainter{@override void paint(Canvas c,Size s){final p=Path()..moveTo(0,s.height*.78)..quadraticBezierTo(s.width*.18,s.height*.45,s.width*.32,s.height*.72)..quadraticBezierTo(s.width*.48,s.height*.94,s.width*.62,s.height*.38)..quadraticBezierTo(s.width*.8,s.height*.65,s.width,s.height*.12);c.drawPath(p,Paint()..color=_amber..style=PaintingStyle.stroke..strokeWidth=2..strokeCap=StrokeCap.round);}@override bool shouldRepaint(covariant CustomPainter old)=>false;}
class _ScheduleCard extends StatelessWidget{const _ScheduleCard({required this.name,required this.detail,required this.time,required this.onTap});final String name,detail,time;final VoidCallback onTap;@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(21),border:Border.all(color:Colors.white10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(name,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:_ink,fontSize:14,fontWeight:FontWeight.w700)),const SizedBox(height:4),Text(detail,style:const TextStyle(color:_muted,fontSize:10))])),const Icon(Icons.alarm_on_rounded,color:_indigo,size:21)]),const SizedBox(height:17),Center(child:Text(time+' • FOKUS',style:const TextStyle(color:_amber2,fontSize:10,fontWeight:FontWeight.w700,fontFamily:'monospace'))),const SizedBox(height:8),ClipRRect(borderRadius:BorderRadius.circular(20),child:SizedBox(height:9,child:Row(children:[Expanded(flex:2,child:Container(color:_high)),Expanded(flex:5,child:Container(decoration:const BoxDecoration(gradient:LinearGradient(colors:[_amber2,_amber,_indigo])))),Expanded(flex:3,child:Container(color:_high))]))),const SizedBox(height:9),Row(children:[const Icon(Icons.sync_rounded,color:_amber2,size:15),const SizedBox(width:6),const Expanded(child:Text('Sinkron otomatis dengan jadwal',style:TextStyle(color:_muted,fontSize:10))),TextButton(onPressed:onTap,child:const Text('EDIT JADWAL',style:TextStyle(color:_amber2,fontSize:9,fontWeight:FontWeight.w800)))])]));}
class _AppTile extends ConsumerWidget {
 const _AppTile({required this.app});
 final InstalledApp app;
 @override Widget build(BuildContext context, WidgetRef ref) {
  final loader=ref.watch(appIconLoaderProvider);
  Widget icon(String? path) {
   if(path==null) return Container(width:34,height:34,decoration:BoxDecoration(color:_high,borderRadius:BorderRadius.circular(10)),child:const Icon(Icons.android_rounded,color:_muted,size:20));
   return ClipRRect(borderRadius:BorderRadius.circular(10),child:Image.file(File(path),width:34,height:34,fit:BoxFit.cover,cacheWidth:(34*MediaQuery.devicePixelRatioOf(context)).round(),errorBuilder:(_,__,___)=>Container(width:34,height:34,decoration:BoxDecoration(color:_high,borderRadius:BorderRadius.circular(10)),child:const Icon(Icons.android_rounded,color:_muted,size:20))));
  }
  final Widget appIcon=loader.isResolved(app)?icon(loader.resolvedPath(app)):FutureBuilder<String?>(future:loader.pathFor(app),builder:(_,snap)=>snap.connectionState==ConnectionState.done?icon(snap.data):Container(width:34,height:34,decoration:BoxDecoration(color:_high,borderRadius:BorderRadius.circular(10)),child:const Icon(Icons.apps_rounded,color:_muted,size:18)));
  return Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:9),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(17),border:Border.all(color:Colors.white10)),child:Row(children:[appIcon,const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[Text(app.label,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:_ink,fontSize:11,fontWeight:FontWeight.w700)),const SizedBox(height:3),const Text('TERKUNCI',style:TextStyle(color:_amber,fontSize:9))])),const Icon(Icons.lock_rounded,color:_amber,size:15)]));
 }
}
class _EmptyApps extends StatelessWidget{const _EmptyApps();@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.all(17),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(17),border:Border.all(color:Colors.white10)),child:const Row(children:[Icon(Icons.apps_rounded,color:_amber,size:22),SizedBox(width:11),Expanded(child:Text('Belum ada aplikasi dibatasi. Pilih aplikasi melalui menu Sesuaikan.',style:TextStyle(color:_muted,fontSize:11)))]));}
String _clock(DateTime d)=>d.hour.toString().padLeft(2,'0')+':'+d.minute.toString().padLeft(2,'0');
String _minute(int n)=>(n~/60).toString().padLeft(2,'0')+':'+(n%60).toString().padLeft(2,'0');
String _fmtDuration(int n)=>(n~/3600).toString().padLeft(2,'0')+':'+((n%3600)~/60).toString().padLeft(2,'0')+':'+(n%60).toString().padLeft(2,'0');
String _days(Set<int> v){const d=['Sen','Sel','Rab','Kam','Jum','Sab','Min'];if(v.length==7)return 'Setiap hari • Rutinitas terjadwal';final s=v.toList()..sort();return s.map((n)=>d[n-1]).join(' • ');}
