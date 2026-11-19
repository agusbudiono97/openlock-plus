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
 static bool dark=true;
 static Color bg=const Color(0xFF0C0D14), panel=const Color(0xFF171927), high=const Color(0xFF292D43);
 static Color border=const Color(0x1AFFFFFF), borderStrong=const Color(0x22FFFFFF);
 static Color ink=const Color(0xFFF1F0F7), muted=const Color(0xFF9D9BB3), amber=const Color(0xFFFF9E42), amber2=const Color(0xFFFFB259), indigo=const Color(0xFF8B5CF6);
 static void apply(bool value) {
  dark=value;
  bg=dark?const Color(0xFF0C0D14):const Color(0xFFF6F8FC);
  panel=dark?const Color(0xFF171927):const Color(0xFFFFFFFF);
  high=dark?const Color(0xFF292D43):const Color(0xFFE8EDF4);
  ink=dark?const Color(0xFFF1F0F7):const Color(0xFF1F2937);
  muted=dark?const Color(0xFF9D9BB3):const Color(0xFF475569);
  amber=dark?const Color(0xFFFF9E42):const Color(0xFFFF8A3D);
  amber2=dark?const Color(0xFFFFB259):const Color(0xFFC65F1C);
  indigo=dark?const Color(0xFF8B5CF6):const Color(0xFF7B61FF);
  border=dark?const Color(0x1AFFFFFF):const Color(0xFFE2E8F0);
  borderStrong=dark?const Color(0x22FFFFFF):const Color(0xFFCBD5E1);
 }
}
Color get _bg=>_HomePalette.bg; Color get _panel=>_HomePalette.panel; Color get _high=>_HomePalette.high;
Color get _ink=>_HomePalette.ink; Color get _muted=>_HomePalette.muted; Color get _amber=>_HomePalette.amber; Color get _amber2=>_HomePalette.amber2; Color get _indigo=>_HomePalette.indigo;

class HomeDashboardScreen extends ConsumerStatefulWidget {
 const HomeDashboardScreen({super.key});
 @override ConsumerState<HomeDashboardScreen> createState()=>_HomeDashboardScreenState();
}
class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> with SingleTickerProviderStateMixin{
 Timer? _timer; DateTime _now=DateTime.now();
 late final AnimationController _glowController;
 @override void initState(){super.initState();_glowController=AnimationController(vsync:this,duration:const Duration(milliseconds:3600));_timer=Timer.periodic(const Duration(seconds:1),(_){if(mounted)setState(()=>_now=DateTime.now());});}
 @override void dispose(){_timer?.cancel();_glowController.dispose();super.dispose();}
 @override Widget build(BuildContext context){
  final isDark=Theme.of(context).brightness==Brightness.dark;
  _HomePalette.apply(isDark);
  final config=ref.watch(configControllerProvider).valueOrNull??LockConfig.empty;
  final apps=ref.watch(installedAppsProvider).valueOrNull??const [];
  final events=ref.watch(intruderControllerProvider).valueOrNull??const [];
  final schedules=config.schedules.where((s)=>s.enabled).toList();
  final locked=apps.where((a)=>config.lockedPackages.contains(a.packageName)).toList();
  final active=config.strictModeActiveAt(_now), end=config.strictModeEndsAtMillis;
  if(active){if(!_glowController.isAnimating)_glowController.repeat();}else if(_glowController.isAnimating){_glowController.stop();_glowController.value=0;}
  final started=config.strictModeStartedAtMillis;
  final left=active&&end!=null?math.max(0,((end-_now.millisecondsSinceEpoch)/1000).floor()):0;
  final timer=end==null?'∞':_fmtDuration(left);
  return Scaffold(backgroundColor:_bg,body:SafeArea(bottom:false,child:LayoutBuilder(builder:(context,constraints)=>Center(child:SizedBox(width:math.min(constraints.maxWidth,560),height:constraints.maxHeight,child:ListView(padding:const EdgeInsets.fromLTRB(18,16,18,28),children:[
   Row(children:[Container(width:48,height:48,decoration:BoxDecoration(borderRadius:BorderRadius.circular(15),gradient:LinearGradient(colors:[Color(0xFF393047),_high]),border:Border.all(color:_HomePalette.borderStrong)),child:Icon(Icons.shield_rounded,color:_amber,size:27)),SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('OpenLock',style:TextStyle(color:_ink,fontSize:22,fontWeight:FontWeight.w800)),SizedBox(height:2),const SizedBox.shrink()])),Material(color:Colors.transparent,child:InkWell(onTap:()=>context.go(AppRoutes.settings),borderRadius:BorderRadius.circular(14),child:Container(width:42,height:42,decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(14),border:Border.all(color:Colors.white12)),child:Icon(Icons.person_outline_rounded,color:_muted,size:21))))]),
   SizedBox(height:22),
   _Pill(message:events.isEmpty?'OpenLock siap menjaga fokusmu':_clock(events.first.timestamp)+' WIB • Percobaan akses tercatat'),
   SizedBox(height:18),
   _Hero(active:active,glowAnimation:_glowController,timer:active?timer:'--:--:--',target:end==null?null:DateTime.fromMillisecondsSinceEpoch(end),onTap:()=>context.push(AppRoutes.strictMode)),
   SizedBox(height:16),
   Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Expanded(flex:3,child:_Bento(title:'STATUS KUBAH',icon:Icons.verified_user_rounded,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(events.length.toString()+' BLOKIR',style:TextStyle(color:_ink,fontSize:28,fontWeight:FontWeight.w800)),Text('Percobaan aplikasi ditangkal',style:TextStyle(color:_muted,fontSize:11)),SizedBox(height:14),const _Sparkline()]))),
    SizedBox(width:10),
    Expanded(flex:2,child:Column(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[_Mini(title:'TERKUNCI',icon:Icons.lock_rounded,value:config.lockedPackages.length.toString(),suffix:'Aplikasi',tint:_amber2),SizedBox(height:10),_Mini(title:'JADWAL',icon:Icons.alarm_on_rounded,value:schedules.length.toString(),suffix:'Aktif',tint:_indigo)])),
   ]),
   SizedBox(height:16),
   _ScheduleCard(name:schedules.isEmpty?'Jadwal Jam Kerja Produktif':schedules.first.name,detail:schedules.isEmpty?'Belum ada rutinitas terjadwal':_days(schedules.first.weekdays),time:schedules.isEmpty?'—':_minute(schedules.first.startMinutes)+' – '+_minute(schedules.first.endMinutes),onTap:()=>context.go(AppRoutes.schedules)),
   SizedBox(height:16),
   Row(children:[Expanded(child:Text('Aplikasi Dibatasi',style:TextStyle(color:_ink,fontSize:16,fontWeight:FontWeight.w700))),TextButton(onPressed:()=>context.go(AppRoutes.apps),child:Text('SESUAIKAN',style:TextStyle(color:_amber2,fontSize:10,fontWeight:FontWeight.w800)))]),
   if(locked.isEmpty)const _EmptyApps() else GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:math.min(locked.length,4),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,mainAxisSpacing:10,crossAxisSpacing:10,mainAxisExtent:68),itemBuilder:(_,i)=>_AppTile(app:locked[i])),
   SizedBox(height:16),
   Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(17),border:Border.all(color:_amber.withValues(alpha:.15))),child:Row(children:[Icon(Icons.psychology_rounded,color:_amber2,size:22),SizedBox(width:11),Expanded(child:Text('“Disiplin adalah memilih antara apa yang kamu inginkan sekarang dan apa yang paling kamu inginkan nanti.”',style:TextStyle(color:_muted,fontSize:11,height:1.45,fontStyle:FontStyle.italic)))])),
  ]))))));
 }
}
class _Pill extends StatelessWidget{const _Pill({required this.message});final String message;@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.symmetric(horizontal:13,vertical:11),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(30),border:Border.all(color:_HomePalette.border)),child:Row(children:[Container(width:8,height:8,decoration:BoxDecoration(color:_amber,shape:BoxShape.circle)),SizedBox(width:9),Expanded(child:Text(message,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:_muted,fontSize:10))),SizedBox(width:6),Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:_amber.withValues(alpha:.1),borderRadius:BorderRadius.circular(20),border:Border.all(color:_amber.withValues(alpha:.3))),child:Row(children:[Icon(Icons.verified_rounded,color:_amber,size:12),SizedBox(width:4),Text('AMAN',style:TextStyle(color:_amber2,fontSize:9,fontWeight:FontWeight.w800))]))]));}
class _Hero extends StatelessWidget{const _Hero({required this.active,required this.glowAnimation,required this.timer,required this.target,required this.onTap});final bool active;final Animation<double> glowAnimation;final String timer;final DateTime? target;final VoidCallback onTap;@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.fromLTRB(18,18,18,17),decoration:BoxDecoration(borderRadius:BorderRadius.circular(30),gradient:_HomePalette.dark?const RadialGradient(center:Alignment(0,-.65),radius:1.35,colors:[Color(0xFF30263D),Color(0xFF171927),Color(0xFF171927)]):null,border:Border.all(color:_HomePalette.borderStrong),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha: _HomePalette.dark ? .35 : .07),blurRadius:28,offset:const Offset(0,12)),BoxShadow(color:_amber.withValues(alpha: _HomePalette.dark ? .045 : .035),blurRadius:38,offset:const Offset(-35,-24)),BoxShadow(color:_indigo.withValues(alpha: _HomePalette.dark ? .10 : .045),blurRadius:42,offset:const Offset(35,35))]),child:Column(children:[
 SizedBox(width:264,height:264,child:Stack(alignment:Alignment.center,children:[RepaintBoundary(child:CustomPaint(size:const Size(264,264),painter:_Dial(glowAnimation))),Column(mainAxisSize:MainAxisSize.min,children:[
 Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),decoration:BoxDecoration(color:_amber.withValues(alpha:.13),borderRadius:BorderRadius.circular(24),border:Border.all(color:_amber.withValues(alpha:.35))),child:Text(active?'MODE KETAT AKTIF':'MODE KETAT NONAKTIF',style:TextStyle(color:_amber2,fontSize:9,fontWeight:FontWeight.w800,letterSpacing:1.1))),
 SizedBox(height:12),Text('SISA WAKTU TERKUNCI',style:TextStyle(color:_muted,fontSize:10,letterSpacing:1.8)),SizedBox(height:4),Text(timer,style:TextStyle(color:_ink,fontSize:34,fontWeight:FontWeight.w800,letterSpacing:-1)),SizedBox(height:7),
 Text(target==null?'Target: Tanpa batas waktu':'Target: '+_clock(target!)+' WIB',style:TextStyle(color:_muted,fontSize:10))
 ])])),
 SizedBox(height:8),Material(color:Colors.transparent,child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(19),child:Ink(padding:const EdgeInsets.symmetric(horizontal:14,vertical:13),decoration:BoxDecoration(gradient:LinearGradient(colors:[_high,(_HomePalette.dark?const Color(0xFF38304F):const Color(0xFFE8EDF4))]),borderRadius:BorderRadius.circular(19),border:Border.all(color:Colors.white12)),child:Row(children:[Icon(Icons.lock_clock_rounded,color:_amber2,size:24),SizedBox(width:11),Expanded(child:Text('KELOLA MODE KETAT',style:TextStyle(color:_ink,fontSize:11,fontWeight:FontWeight.w800,letterSpacing:1.1))),Icon(Icons.tune_rounded,color:_amber,size:20)]))))]));}
class _Dial extends CustomPainter {
 _Dial(this.animation):super(repaint:animation);
 final Animation<double> animation;
 @override void paint(Canvas canvas, Size size) {
  final phase=animation.value;
  final center=Offset(size.width/2,size.height/2), radius=size.width*.405;
  final rect=Rect.fromCircle(center:center,radius:radius);
  canvas.drawCircle(center,radius+17,Paint()..style=PaintingStyle.stroke..strokeWidth=1..color=Colors.white.withValues(alpha:.035));
  final orbit=Paint()..style=PaintingStyle.stroke..strokeWidth=1..color=const Color(0xFF777B9A).withValues(alpha:.22);
  for(var i=0;i<72;i++){
   final a=-math.pi/2+i*math.pi*2/72;
   final p1=Offset(center.dx+math.cos(a)*(radius+10),center.dy+math.sin(a)*(radius+10));
   final p2=Offset(center.dx+math.cos(a)*(radius+12),center.dy+math.sin(a)*(radius+12));
   canvas.drawLine(p1,p2,orbit);
  }
  final colors=[_amber2,Color(0xFFFFB65F),Color(0xFFFFB260),Color(0xFFFFAE60),Color(0xFFFFAA5F),Color(0xFFFFA65E),Color(0xFFFFA15D),Color(0xFFFF9C5D),Color(0xFFFF975E),Color(0xFFFF9262),Color(0xFFFF8D68),Color(0xFFF98770),Color(0xFFF1817B),Color(0xFFEA7D8A),Color(0xFFE27C9A),Color(0xFFD77BAA),Color(0xFFCA78BE),Color(0xFFBC76D4),Color(0xFFAA6FE6),Color(0xFF9865F0),_indigo,Color(0xFF7770F2),Color(0xFF8A6CF4),Color(0xFF9A70F5),_amber2];
  const stops=<double>[0,.06,.10,.14,.18,.22,.26,.30,.34,.38,.42,.46,.50,.54,.58,.62,.66,.70,.74,.78,.82,.86,.90,.95,1];
  final wave=.5-.5*math.cos(phase*math.pi*2);
  Color colorAt(double t){
   var index=0;
   while(index<stops.length-2 && t>stops[index+1]){index++;}
   final span=stops[index+1]-stops[index];
   final double local=span==0?0.0:(t-stops[index])/span;
   return Color.lerp(colors[index],colors[index+1],local)!;
  }
  // Render the halo as overlapping colored arc segments, matching the
  // seam-free approach used by the earlier dark-theme ring. Avoid applying
  // a SweepGradient shader to a blurred circle: its shader boundary can show
  // as a horizontal cutoff on light surfaces.
  void drawHalo({required double width,required double opacity,required double blur}){
   const haloSegments=240;
   const haloStep=math.pi*2/haloSegments;
   final haloPaint=Paint()
    ..style=PaintingStyle.stroke
    ..strokeWidth=width
    ..strokeCap=StrokeCap.round
    ..maskFilter=MaskFilter.blur(BlurStyle.normal,blur);
   for(var i=0;i<haloSegments;i++){
    haloPaint.color=colorAt((i+.5)/haloSegments).withValues(alpha:opacity);
    canvas.drawArc(rect,-math.pi/2+i*haloStep,haloStep+.008,false,haloPaint);
   }
  }
  drawHalo(width:38+8*wave,opacity:.25+.12*wave,blur:13+4*wave);
  drawHalo(width:22+4*wave,opacity:.34+.12*wave,blur:5+2*wave);
  // Crisp colored base ring remains fully visible and retains the seam-free segmented gradient.
  final ringPaint=Paint()..style=PaintingStyle.stroke..strokeWidth=11..strokeCap=StrokeCap.butt;
  const count=360;
  const step=math.pi*2/count;
  for(var i=0;i<count;i++){
   ringPaint.color=colorAt(i/count);
   canvas.drawArc(rect,-math.pi/2+i*step,step+.006,false,ringPaint);
  }
  canvas.drawCircle(center,radius,Paint()..style=PaintingStyle.stroke..strokeWidth=1..color=Colors.white.withValues(alpha:.055));
 }
 @override bool shouldRepaint(covariant _Dial old)=>old.animation!=animation;
}
class _Bento extends StatelessWidget{const _Bento({required this.title,required this.icon,required this.child});final String title;final IconData icon;final Widget child;@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(21),border:Border.all(color:Colors.white10)),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(title,style:TextStyle(color:_muted,fontSize:10,letterSpacing:1,fontWeight:FontWeight.w700))),Icon(icon,color:_amber,size:18)]),SizedBox(height:18),child]));}
class _Mini extends StatelessWidget{const _Mini({required this.title,required this.icon,required this.value,required this.suffix,required this.tint});final String title,value,suffix;final IconData icon;final Color tint;@override Widget build(BuildContext c)=>Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(19),border:Border.all(color:Colors.white10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Row(children:[Expanded(child:Text(title,style:TextStyle(color:_muted,fontSize:9,fontWeight:FontWeight.w700,letterSpacing:.6))),Icon(icon,color:tint,size:16)]),Row(crossAxisAlignment:CrossAxisAlignment.baseline,textBaseline:TextBaseline.alphabetic,children:[Text(value,style:TextStyle(color:_ink,fontSize:21,fontWeight:FontWeight.w800)),SizedBox(width:5),Flexible(child:Text(suffix,style:TextStyle(color:tint,fontSize:9)))])]));}
class _Sparkline extends StatelessWidget{const _Sparkline();@override Widget build(BuildContext c)=>SizedBox(height:28,child:CustomPaint(painter:_Spark()));}
class _Spark extends CustomPainter{@override void paint(Canvas c,Size s){final p=Path()..moveTo(0,s.height*.78)..quadraticBezierTo(s.width*.18,s.height*.45,s.width*.32,s.height*.72)..quadraticBezierTo(s.width*.48,s.height*.94,s.width*.62,s.height*.38)..quadraticBezierTo(s.width*.8,s.height*.65,s.width,s.height*.12);c.drawPath(p,Paint()..color=_amber..style=PaintingStyle.stroke..strokeWidth=2..strokeCap=StrokeCap.round);}@override bool shouldRepaint(covariant CustomPainter old)=>false;}
class _ScheduleCard extends StatelessWidget{const _ScheduleCard({required this.name,required this.detail,required this.time,required this.onTap});final String name,detail,time;final VoidCallback onTap;@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(21),border:Border.all(color:Colors.white10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(name,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:_ink,fontSize:14,fontWeight:FontWeight.w700)),SizedBox(height:4),Text(detail,style:TextStyle(color:_muted,fontSize:10))])),Icon(Icons.alarm_on_rounded,color:_indigo,size:21)]),SizedBox(height:17),Center(child:Text(time+' • FOKUS',style:TextStyle(color:_amber2,fontSize:10,fontWeight:FontWeight.w700,fontFamily:'monospace'))),SizedBox(height:8),ClipRRect(borderRadius:BorderRadius.circular(20),child:SizedBox(height:9,child:Row(children:[Expanded(flex:2,child:Container(color:_high)),Expanded(flex:5,child:Container(decoration:BoxDecoration(gradient:LinearGradient(colors:[_amber2,_amber,_indigo])))),Expanded(flex:3,child:Container(color:_high))]))),SizedBox(height:9),Row(children:[Icon(Icons.sync_rounded,color:_amber2,size:15),SizedBox(width:6),Expanded(child:Text('Sinkron otomatis dengan jadwal',style:TextStyle(color:_muted,fontSize:10))),TextButton(onPressed:onTap,child:Text('EDIT JADWAL',style:TextStyle(color:_amber2,fontSize:9,fontWeight:FontWeight.w800)))])]));}
class _AppTile extends ConsumerWidget {
 const _AppTile({required this.app});
 final InstalledApp app;
 @override Widget build(BuildContext context, WidgetRef ref) {
  final loader=ref.watch(appIconLoaderProvider);
  Widget icon(String? path) {
   if(path==null) return Container(width:34,height:34,decoration:BoxDecoration(color:_high,borderRadius:BorderRadius.circular(10)),child:Icon(Icons.android_rounded,color:_muted,size:20));
   return ClipRRect(borderRadius:BorderRadius.circular(10),child:Image.file(File(path),width:34,height:34,fit:BoxFit.cover,cacheWidth:(34*MediaQuery.devicePixelRatioOf(context)).round(),errorBuilder:(_,__,___)=>Container(width:34,height:34,decoration:BoxDecoration(color:_high,borderRadius:BorderRadius.circular(10)),child:Icon(Icons.android_rounded,color:_muted,size:20))));
  }
  final Widget appIcon=loader.isResolved(app)?icon(loader.resolvedPath(app)):FutureBuilder<String?>(future:loader.pathFor(app),builder:(_,snap)=>snap.connectionState==ConnectionState.done?icon(snap.data):Container(width:34,height:34,decoration:BoxDecoration(color:_high,borderRadius:BorderRadius.circular(10)),child:Icon(Icons.apps_rounded,color:_muted,size:18)));
  return Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:9),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(17),border:Border.all(color:Colors.white10)),child:Row(children:[appIcon,SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[Text(app.label,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:_ink,fontSize:11,fontWeight:FontWeight.w700)),SizedBox(height:3),Text('TERKUNCI',style:TextStyle(color:_amber,fontSize:9))])),Icon(Icons.lock_rounded,color:_amber,size:15)]));
 }
}
class _EmptyApps extends StatelessWidget{const _EmptyApps();@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.all(17),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(17),border:Border.all(color:Colors.white10)),child:Row(children:[Icon(Icons.apps_rounded,color:_amber,size:22),SizedBox(width:11),Expanded(child:Text('Belum ada aplikasi dibatasi. Pilih aplikasi melalui menu Sesuaikan.',style:TextStyle(color:_muted,fontSize:11)))]));}
String _clock(DateTime d)=>d.hour.toString().padLeft(2,'0')+':'+d.minute.toString().padLeft(2,'0');
String _minute(int n)=>(n~/60).toString().padLeft(2,'0')+':'+(n%60).toString().padLeft(2,'0');
String _fmtDuration(int n)=>(n~/3600).toString().padLeft(2,'0')+':'+((n%3600)~/60).toString().padLeft(2,'0')+':'+(n%60).toString().padLeft(2,'0');
String _days(Set<int> v){const d=['Sen','Sel','Rab','Kam','Jum','Sab','Min'];if(v.length==7)return 'Setiap hari • Rutinitas terjadwal';final s=v.toList()..sort();return s.map((n)=>d[n-1]).join(' • ');}
