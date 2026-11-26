import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openlock/src/core/interfaces/enforcement_bridge.dart';
import 'package:openlock/src/core/router/app_router.dart';
import 'package:openlock/src/features/apps/providers/apps_providers.dart';
import 'package:openlock/src/features/enforcement/models/lock_config.dart';
import 'package:openlock/src/features/enforcement/providers/config_providers.dart';

class AppPickerScreen extends ConsumerStatefulWidget {
  const AppPickerScreen({super.key});
  @override
  ConsumerState<AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends ConsumerState<AppPickerScreen> {
  static const amber = Color(0xFFFFB020);
  static const bg = Color(0xFF090A0F);
  static const surface = Color(0xFF0D0E15);
  static const surface2 = Color(0xFF161824);
  static const borderDark = Color(0xFF252938);
  static const categories = ['Semua', 'Sosmed', 'Game', 'Finansial', 'Sistem'];
  final search = TextEditingController();
  final Set<String> pending = {};
  String category = 'Semua';
  bool seeded = false;
  bool saving = false;
  bool onlyLocked = false;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  String categoryOf(InstalledApp app) {
    final v = '${app.label} ${app.packageName}'.toLowerCase();
    if (['game', 'bussimulator', 'mobile.legends', 'pubg', 'freefire', 'roblox', 'minecraft'].any(v.contains)) return 'Game';
    if (['instagram', 'facebook', 'whatsapp', 'telegram', 'tiktok', 'twitter', 'snapchat', 'threads', 'messenger'].any(v.contains)) return 'Sosmed';
    if (['bank', 'wallet', 'finance', 'bitget', 'gopay', 'ovo', 'dana', 'shopeepay', 'bca', 'bri', 'mandiri'].any(v.contains)) return 'Finansial';
    if (['android', 'system', 'settings', 'permission', 'authenticator', 'camera'].any(v.contains)) return 'Sistem';
    return 'Lainnya';
  }

  Future<void> apply(LockConfig config) async {
    if (saving || config.strictModeActiveAt(DateTime.now())) return;
    final additions = pending.difference(config.lockedPackages).toList()..sort();
    final removals = config.lockedPackages.difference(pending).toList()..sort();
    if (additions.isEmpty && removals.isEmpty) return;
    setState(() => saving = true);
    try {
      final controller = ref.read(configControllerProvider.notifier);
      for (final p in additions) { await controller.toggleApp(p); }
      for (final p in removals) { await controller.toggleApp(p); }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Proteksi aplikasi berhasil diperbarui.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Perubahan belum berhasil disimpan: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? bg : const Color(0xFFF6F7FA);
    final panel = dark ? surface : Colors.white;
    final panel2 = dark ? surface2 : const Color(0xFFF0F1F5);
    final border = dark ? borderDark : const Color(0xFFE2E5EC);
    final ink = dark ? const Color(0xFFF8FAFC) : const Color(0xFF151923);
    final muted = dark ? const Color(0xFF9AA3B5) : const Color(0xFF667085);
    final listAsync = ref.watch(installedAppsProvider);
    final configAsync = ref.watch(configControllerProvider);
    final config = configAsync.valueOrNull ?? LockConfig.empty;
    final apps = listAsync.valueOrNull ?? <InstalledApp>[];
    final frozen = config.strictModeActiveAt(DateTime.now());

    if (configAsync.hasValue && !seeded) {
      pending..clear()..addAll(config.lockedPackages);
      seeded = true;
    }
    final count = apps.where((a) => pending.contains(a.packageName)).length;
    final freeCount = (apps.length - count).clamp(0, apps.length);
    final q = search.text.trim().toLowerCase();
    final visible = apps.where((a) {
      final matches = q.isEmpty || a.label.toLowerCase().contains(q) || a.packageName.toLowerCase().contains(q);
      final cat = categoryOf(a);
      return matches && (category == 'Semua' || cat == category) && (!onlyLocked || pending.contains(a.packageName));
    }).toList()..sort((a,b) {
      final al = pending.contains(a.packageName), bl = pending.contains(b.packageName);
      if (al != bl) return al ? -1 : 1;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    final counts = {for (final c in categories) c: c == 'Semua' ? apps.length : apps.where((a) => categoryOf(a) == c).length};
    final changed = pending.length != config.lockedPackages.length || !pending.containsAll(config.lockedPackages) || !config.lockedPackages.containsAll(pending);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: false,
        child: Stack(children: [
          Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: Row(children: [
                _BackButton(panel: panel2, border: border, ink: ink, onTap: () => context.go(AppRoutes.home)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('KENDALI AKSES', style: TextStyle(color: amber, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                  Text('Aplikasi Terlindungi', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: ink, fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -.55)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  decoration: BoxDecoration(color: amber.withValues(alpha: .09), borderRadius: BorderRadius.circular(24), border: Border.all(color: amber.withValues(alpha: .32))),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [_PulseDot(), SizedBox(width: 7), Text('Vault Siaga', style: TextStyle(color: amber, fontSize: 11, fontWeight: FontWeight.w700))]),
                ),
              ]),
            ),
            Expanded(child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 3, 20, 112),
              physics: const BouncingScrollPhysics(),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16,16,16,13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(begin: Alignment.topLeft,end: Alignment.bottomRight,colors: dark ? const [Color(0xFF20202B),Color(0xFF15151F),Color(0xFF211B25)] : const [Colors.white,Color(0xFFF8F4EC),Color(0xFFF7F0F3)]),
                    border: Border.all(color: dark ? Colors.white.withValues(alpha:.11) : const Color(0xFFE5D9C9)),
                    boxShadow: [BoxShadow(color: amber.withValues(alpha: dark ? .08 : .04),blurRadius:26,offset:const Offset(0,8))],
                  ),
                  child: Column(children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start,children: [
                      Container(width:48,height:48,decoration:BoxDecoration(color:dark?const Color(0xFF171722):const Color(0xFFFFF1C7),borderRadius:BorderRadius.circular(16),border:Border.all(color:amber.withValues(alpha:.8)),boxShadow:[BoxShadow(color:amber.withValues(alpha: dark ? .28 : .12),blurRadius:17)]),child:const Icon(Icons.shield_rounded,color:amber,size:25)),
                      const SizedBox(width:13),
                      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Text('Isolasi & Disiplin Digital',style:TextStyle(color:ink,fontSize:13,fontWeight:FontWeight.w700)),
                        const SizedBox(height:5),
                        Text('Pilih aplikasi yang ingin kamu jauhkan sementara dari jangkauan refleks untuk menjaga fokus optimal.',style:TextStyle(color:muted,fontSize:11.5,height:1.55)),
                      ])),
                    ]),
                    Padding(padding:const EdgeInsets.only(top:13),child:Divider(height:1,color:dark?Colors.white.withValues(alpha:.07):border)),
                    const SizedBox(height:11),
                    Row(children:[
                      Expanded(child:_SummaryDot(color:const Color(0xFF34D399),label:'$freeCount Aplikasi Bebas',textColor:muted)),
                      Expanded(child:_SummaryDot(color:amber,label:'$count Terkunci Aktif',textColor:amber)),
                      Text('Kapasitas: ',style:TextStyle(color:muted,fontSize:9.5)),
                      Text('Tinggi',style:TextStyle(color:ink,fontSize:9.5,fontWeight:FontWeight.w700)),
                    ]),
                  ]),
                ),
                const SizedBox(height:18),
                TextField(
                  controller:search,onChanged:(_)=>setState((){}),
                  style:TextStyle(color:ink,fontSize:12),cursorColor:amber,
                  decoration:InputDecoration(
                    hintText:'Cari nama atau paket aplikasi...',hintStyle:TextStyle(color:muted,fontSize:11.5),
                    prefixIcon:Icon(Icons.search_rounded,color:muted,size:18),
                    suffixIcon: search.text.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(right: 9, top: 9, bottom: 9),
                            child: Container(
                              width: 29, alignment: Alignment.center,
                              decoration: BoxDecoration(color: dark ? const Color(0xFF202331) : const Color(0xFFF3F5F9), borderRadius: BorderRadius.circular(6), border: Border.all(color: border)),
                              child: Text('⌘K', style: TextStyle(color: muted, fontSize: 9, fontWeight: FontWeight.w600)),
                            ),
                          )
                        : IconButton(onPressed:(){search.clear();setState((){});},icon:Icon(Icons.close,color:muted,size:17)),
                    filled:true,fillColor:panel2.withValues(alpha:.78),
                    contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:12),
                    enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide(color:border)),
                    focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide(color:amber.withValues(alpha:.7))),
                  ),
                ),
                const SizedBox(height:11),
                SizedBox(height:31,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:categories.length,separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(context,i){
                  final c=categories[i], selected=category==c;
                  return ChoiceChip(
                    label:Text('$c (${counts[c]??0})'),selected:selected,onSelected:(_)=>setState(()=>category=c),showCheckmark:false,
                    labelStyle:TextStyle(color:selected?const Color(0xFF17120A):ink,fontSize:10.5,fontWeight:selected?FontWeight.w800:FontWeight.w500),
                    backgroundColor:panel2,selectedColor:const Color(0xFFF59E0B),side:BorderSide(color:selected?const Color(0xFFF59E0B):border),
                    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(9)),padding:const EdgeInsets.symmetric(horizontal:1),
                  );
                })),
                const SizedBox(height:17),
                Row(children:[
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text('Aplikasi terkunci',style:TextStyle(color:ink,fontSize:12,fontWeight:FontWeight.w800)),
                    const SizedBox(height:3),
                    Text('$count aplikasi dipilih dari ${apps.length} aplikasi terpasang',style:TextStyle(color:muted,fontSize:10.5)),
                  ])),
                  InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => _showFilterSheet(context, dark, onlyLocked, (value) => setState(() => onlyLocked = value)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(color: panel2, borderRadius: BorderRadius.circular(9), border: Border.all(color: border)),
                      child: Row(children: [
                        const Icon(Icons.filter_list_rounded, color: amber, size: 14),
                        const SizedBox(width: 5),
                        Text('Filter', style: TextStyle(color: ink, fontSize: 10, fontWeight: FontWeight.w600)),
                        if (onlyLocked) ...[const SizedBox(width: 5), const Icon(Icons.circle, color: amber, size: 6)],
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height:11),
                if(listAsync.isLoading) const _LoadingApps()
                else if(listAsync.hasError) _MessageCard(icon:Icons.error_outline_rounded,title:'Gagal memuat aplikasi',message:'Daftar aplikasi yang terpasang belum tersedia.',ink:ink,muted:muted,panel:panel,border:border)
                else if(visible.isEmpty) _MessageCard(icon:Icons.search_off_rounded,title:'Aplikasi tidak ditemukan',message:'Coba kata pencarian atau kategori lain.',ink:ink,muted:muted,panel:panel,border:border)
                else for(final app in visible) Padding(
                  padding:const EdgeInsets.only(bottom:10),
                  child:_ProtectedAppCard(
                    app:app,selected:pending.contains(app.packageName),frozen:frozen,config:config,ink:ink,muted:muted,panel:panel,border:border,
                    onChanged:(v){if(frozen)return;setState(()=>v?pending.add(app.packageName):pending.remove(app.packageName));},
                  ),
                ),
              ],
            )),
          ]),
          Positioned(left:20,right:20,bottom:7,child:SafeArea(top:false,child:Container(
            padding:const EdgeInsets.all(5),
            decoration:BoxDecoration(color:panel.withValues(alpha:.94),borderRadius:BorderRadius.circular(17),border:Border.all(color:border),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.3),blurRadius:22,offset:const Offset(0,7))]),
            child:Row(children:[
              const SizedBox(width:9),Container(width:9,height:9,decoration:const BoxDecoration(color:amber,shape:BoxShape.circle)),const SizedBox(width:8),
              Expanded(child:Text('$count Terpilih',style:TextStyle(color:ink,fontSize:11,fontWeight:FontWeight.w700))),
              FilledButton.icon(
                onPressed:frozen||!changed||saving?null:()=>apply(config),
                icon:saving?const SizedBox(width:14,height:14,child:CircularProgressIndicator(strokeWidth:2,color:Color(0xFF17120A))):const Icon(Icons.lock_rounded,size:14),
                label:Text(frozen?'Proteksi Aktif':saving?'Menyimpan...':'Terapkan Proteksi'),
                style:FilledButton.styleFrom(backgroundColor:const Color(0xFFF59E0B),foregroundColor:const Color(0xFF17120A),disabledBackgroundColor:const Color(0xFFF59E0B).withValues(alpha:.35),disabledForegroundColor:const Color(0xFF17120A).withValues(alpha:.6),padding:const EdgeInsets.symmetric(horizontal:12,vertical:12),textStyle:const TextStyle(fontSize:10.5,fontWeight:FontWeight.w800),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
              ),
            ]),
          ))),
        ]),
      ),
    );
  }
}


Future<void> _showFilterSheet(BuildContext context, bool dark, bool currentOnlyLocked, ValueChanged<bool> onApply) async {
  var selected = currentOnlyLocked;
  final ink = dark ? const Color(0xFFF8FAFC) : const Color(0xFF151923);
  final muted = dark ? const Color(0xFF9AA3B5) : const Color(0xFF667085);
  final panel = dark ? const Color(0xFF151722) : Colors.white;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: panel,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (sheetContext) => StatefulBuilder(builder: (context, setSheetState) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: muted.withValues(alpha: .35), borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 18),
          Text('Filter aplikasi', style: TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Atur aplikasi yang ingin ditampilkan.', style: TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero, value: selected, activeColor: const Color(0xFFF59E0B), checkColor: const Color(0xFF17120A),
            title: Text('Hanya tampilkan aplikasi terkunci', style: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text('Sembunyikan aplikasi yang belum dipilih.', style: TextStyle(color: muted, fontSize: 11)),
            onChanged: (value) => setSheetState(() => selected = value ?? false),
          ),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: () { onApply(selected); Navigator.of(sheetContext).pop(); },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: const Color(0xFF17120A)),
            child: const Text('Terapkan Filter', style: TextStyle(fontWeight: FontWeight.w800)),
          )),
        ]),
      ),
    )),
  );
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.panel,required this.border,required this.ink,required this.onTap});
  final Color panel,border,ink; final VoidCallback onTap;
  @override Widget build(BuildContext context)=>Material(color:panel,borderRadius:BorderRadius.circular(12),child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(12),child:Container(width:40,height:40,decoration:BoxDecoration(borderRadius:BorderRadius.circular(12),border:Border.all(color:border)),child:Icon(Icons.chevron_left_rounded,color:ink,size:23))));
}

class _PulseDot extends StatelessWidget {
  const _PulseDot();
  @override
  Widget build(BuildContext context) => Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFFFFB020), shape: BoxShape.circle));
}

class _SummaryDot extends StatelessWidget {
  const _SummaryDot({required this.color,required this.label,required this.textColor});
  final Color color,textColor; final String label;
  @override Widget build(BuildContext context)=>Row(children:[Container(width:7,height:7,decoration:BoxDecoration(color:color,shape:BoxShape.circle)),const SizedBox(width:5),Flexible(child:Text(label,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:textColor,fontSize:9.5,fontWeight:FontWeight.w600)))]);
}

String _badgeForCard(InstalledApp app) {
  final v = '${app.label} ${app.packageName}'.toLowerCase();
  if (v.contains('appblock') || v.contains('mobile.soft')) return 'Alat Fokus';
  if (v.contains('authenticator') || v.contains('2fa')) return 'Aman';
  if (['game', 'bussimulator', 'mobile.legends', 'pubg', 'freefire', 'roblox', 'minecraft'].any(v.contains)) return 'Game';
  if (['instagram', 'facebook', 'whatsapp', 'telegram', 'tiktok', 'twitter', 'snapchat', 'threads', 'messenger'].any(v.contains)) return 'Sosmed';
  if (['bank', 'wallet', 'finance', 'bitget', 'gopay', 'ovo', 'dana', 'shopeepay', 'bca', 'bri', 'mandiri'].any(v.contains)) return 'Finansial';
  if (['android', 'system', 'settings', 'permission', 'camera'].any(v.contains)) return 'Sistem';
  return 'Lainnya';
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.label, required this.dark});
  final String label;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'Alat Fokus' => const Color(0xFFE8A51B),
      'Aman' => const Color(0xFF34B98A),
      'Finansial' => const Color(0xFF18B7D0),
      'Game' => const Color(0xFFEF5570),
      'Sosmed' => const Color(0xFFEC6686),
      _ => const Color(0xFF8793A8),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: dark ? .12 : .07), border: Border.all(color: color.withValues(alpha: .6), width: .7), borderRadius: BorderRadius.circular(4)),
      child: Text(label, maxLines: 1, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w600)),
    );
  }
}

class _ProtectedAppCard extends ConsumerWidget {
  const _ProtectedAppCard({required this.app,required this.selected,required this.frozen,required this.config,required this.ink,required this.muted,required this.panel,required this.border,required this.onChanged});
  final InstalledApp app; final bool selected,frozen; final LockConfig config;
  final Color ink,muted,panel,border; final ValueChanged<bool> onChanged;
  @override Widget build(BuildContext context,WidgetRef ref){
    final loader=ref.watch(appIconLoaderProvider);
    Widget iconFor(String? path) => path==null
      ? Container(decoration:BoxDecoration(color:const Color(0xFF334155),borderRadius:BorderRadius.circular(11)),child:const Icon(Icons.android_rounded,color:Color(0xFFE2E8F0),size:24))
      : ClipRRect(borderRadius:BorderRadius.circular(11),child:Image.file(File(path),width:44,height:44,fit:BoxFit.cover,cacheWidth:(44*MediaQuery.devicePixelRatioOf(context)).round(),errorBuilder:(_,__,___)=>const Icon(Icons.android_rounded)));
    final icon = loader.isResolved(app)
      ? iconFor(loader.resolvedPath(app))
      : FutureBuilder<String?>(
          future: loader.pathFor(app),
          builder: (_, snapshot) => snapshot.connectionState == ConnectionState.done
            ? iconFor(snapshot.data)
            : Container(decoration:BoxDecoration(color:const Color(0xFF334155),borderRadius:BorderRadius.circular(11)),child:const Icon(Icons.apps_rounded,color:Color(0xFFE2E8F0),size:22)),
        );
    return AnimatedContainer(duration:const Duration(milliseconds:160),padding:const EdgeInsets.all(11),decoration:BoxDecoration(
      color:selected?panel.withValues(alpha:.94):panel.withValues(alpha:.62),borderRadius:BorderRadius.circular(17),
      border:Border.all(color:selected?const Color(0x66F59E0B):border.withValues(alpha:.8)),
      boxShadow:selected?[BoxShadow(color:const Color(0xFFF59E0B).withValues(alpha:.09),blurRadius:17,spreadRadius:1)]:null,
    ),child:Column(children:[
      Row(children:[
        SizedBox(width:44,height:44,child:ClipRRect(borderRadius:BorderRadius.circular(11),child:icon)),
        const SizedBox(width:12),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children: [
            Flexible(child: Text(app.label,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:ink,fontSize:13,fontWeight:FontWeight.w700))),
            const SizedBox(width: 6),
            _CategoryBadge(label: _badgeForCard(app), dark: Theme.of(context).brightness == Brightness.dark),
          ]),
          const SizedBox(height:3),
          Text(app.packageName,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:muted,fontSize:10,fontFamily:'monospace')),
        ])),
        const SizedBox(width:8),
        Switch(value:selected,onChanged:frozen?null:onChanged,activeThumbColor:Colors.white,activeTrackColor:const Color(0xFFF59E0B),inactiveThumbColor:const Color(0xFFCBD5E1),inactiveTrackColor:const Color(0xFF263244),materialTapTargetSize:MaterialTapTargetSize.shrinkWrap),
      ]),
      if(config.lockedPackages.contains(app.packageName)) Padding(
        padding:const EdgeInsets.only(left:56,top:7),
        child:Row(children:[
          Icon(Icons.notifications_off_outlined,size:16,color:muted),const SizedBox(width:7),
          Expanded(child:Text('Sembunyikan notifikasi',style:TextStyle(color:muted,fontSize:10.5))),
          Switch(value:config.hidesNotificationsFor(app.packageName),onChanged:frozen?null:(v)=>ref.read(configControllerProvider.notifier).setNotificationOverride(app.packageName,v),activeThumbColor:Colors.white,activeTrackColor:const Color(0xFFF59E0B),materialTapTargetSize:MaterialTapTargetSize.shrinkWrap),
        ]),
      ),
    ]));
  }
}

class _LoadingApps extends StatelessWidget {
  const _LoadingApps();
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(children: List.generate(6, (_) => Container(
      height: 68, margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: dark ? const Color(0xFF161824) : Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: dark ? Colors.white10 : const Color(0xFFE2E5EC))),
    )));
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon,required this.title,required this.message,required this.ink,required this.muted,required this.panel,required this.border});
  final IconData icon; final String title,message; final Color ink,muted,panel,border;
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(16),border:Border.all(color:border)),child:Row(children:[
    Icon(icon,color:const Color(0xFFFFB020),size:23),const SizedBox(width:12),
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(title,style:TextStyle(color:ink,fontSize:12,fontWeight:FontWeight.w700)),const SizedBox(height:4),
      Text(message,style:TextStyle(color:muted,fontSize:10.5)),
    ])),
  ]));
}
