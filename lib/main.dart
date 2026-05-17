import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://hfngiuibzxwkekmoujqk.supabase.co',
    anonKey: 'sb_publishable_-FHg2qpgp2Sgipju2SsZKw_nJFtToh8',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0A0A0A)),
      home: const HomeScreen(),
    );
  }
}

const kRed    = Color(0xFFFF2D55);
const kGreen  = Color(0xFF00E676);
const kOrange = Color(0xFFFF6D00);
const kBlue   = Color(0xFF2979FF);
const kBg     = Color(0xFF0A0A0A);
const kCard   = Color(0xFF141414);
const kCard2  = Color(0xFF1C1C1C);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  List clientes          = [];
  List clientesFiltrados = [];

  String filtroEstado  = "Todos";
  String filtroPaquete = "Todos";
  int?   filtroAnio;
  int?   filtroMes;

  List<String> paquetes   = ["Todos"];
  List<int>    listaAnios = [];

  final buscador         = TextEditingController();
  final buscadorClientes = TextEditingController();
  Timer? autoRefresh;
  late TabController _tabController;

  int    totalActivos  = 0;
  int    totalVencidos = 0;
  double ingresosMes   = 0;
  double ingresosAnio  = 0;
  double metaMes       = 18000;
  Map<String, double> ingresosPorMes = {};

  final mesesTexto = ["Enero","Febrero","Marzo","Abril","Mayo","Junio",
    "Julio","Agosto","Septiembre","Octubre","Noviembre","Diciembre"];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    filtroAnio = DateTime.now().year;
    cargarClientes();
    autoRefresh = Timer.periodic(const Duration(seconds: 30), (_) => cargarClientes());
  }

  @override
  void dispose() {
    autoRefresh?.cancel();
    _tabController.dispose();
    buscador.dispose();
    buscadorClientes.dispose();
    super.dispose();
  }

  Future<void> cargarClientes() async {
    final data = await supabase.from('ventas').select().order('fecha_compra', ascending: false);
    Set<String> listaPaquetes = {"Todos"};
    Set<int> anios = {};
    int activos = 0, vencidos = 0;
    double ingresosMesActual = 0, ingresosAnioActual = 0;
    Map<String, double> porMes = {};
    final now = DateTime.now();

    for (var c in data) {
      final fecha = DateTime.tryParse(c['fecha_compra'] ?? '') ?? now;
      anios.add(fecha.year);
      if ((c['paquete'] ?? '').toString().isNotEmpty) listaPaquetes.add(c['paquete']);
      if (now.isAfter(_fechaVencimiento(c))) vencidos++; else activos++;
      if (fecha.year == now.year) {
        final key = mesesTexto[fecha.month - 1];
        porMes[key] = (porMes[key] ?? 0) + (c['monto'] ?? 0).toDouble();
        ingresosAnioActual += (c['monto'] ?? 0).toDouble();
        if (fecha.month == now.month) ingresosMesActual += (c['monto'] ?? 0).toDouble();
      }
    }

    setState(() {
      clientes = data;
      paquetes = listaPaquetes.toList();
      listaAnios = anios.toList()..sort((b, a) => a.compareTo(b));
      totalActivos = activos;
      totalVencidos = vencidos;
      ingresosMes = ingresosMesActual;
      ingresosAnio = ingresosAnioActual;
      ingresosPorMes = porMes;
    });
    aplicarFiltros();
  }

  DateTime _fechaVencimiento(Map c) {
    final fecha = DateTime.tryParse(c['fecha_compra'] ?? '') ?? DateTime.now();
    final meses = (c['meses'] ?? 1) as num;
    return DateTime(fecha.year, fecha.month + meses.toInt(), fecha.day);
  }

  bool estaVencido(Map c) => DateTime.now().isAfter(_fechaVencimiento(c));
  int  diasParaVencer(Map c) => _fechaVencimiento(c).difference(DateTime.now()).inDays;

  String _tiempoRestante(bool vencido, int dias, dynamic mesesComprados) {
    if (vencido) return "VENCIDO";
    if (dias <= 7) return "⚠️ ${dias}d";
    if (dias <= 30) {
      final semanas   = dias ~/ 7;
      final diasExtra = dias % 7;
      return diasExtra > 0 ? "${semanas}sem ${diasExtra}d" : "${semanas}sem";
    }
    final mesesRest = dias ~/ 30;
    final diasRest  = dias % 30;
    return diasRest > 0 ? "${mesesRest}m ${diasRest}d" : "${mesesRest}m";
  }

  void aplicarFiltros() {
    final texto    = buscador.text.toLowerCase().replaceAll(' ', '');
    final res = clientes.where((c) {
      final nombre  = (c['nombre_fb'] ?? '').toLowerCase();
      final email   = (c['email']    ?? '').toLowerCase();
      final tel     = (c['telefono'] ?? '').toLowerCase().replaceAll(' ', '');
      final paquete = (c['paquete']  ?? '');
      final fecha   = DateTime.tryParse(c['fecha_compra'] ?? '') ?? DateTime.now();
      final vencido = estaVencido(c);
      if (texto.isNotEmpty && !nombre.contains(texto) && !email.contains(texto) && !tel.contains(texto)) return false;
      if (filtroEstado  == "Vencidos" && !vencido) return false;
      if (filtroEstado  == "Activos"  &&  vencido) return false;
      if (filtroPaquete != "Todos"    && paquete != filtroPaquete) return false;
      if (filtroAnio    != null       && fecha.year  != filtroAnio) return false;
      if (filtroMes     != null       && fecha.month != filtroMes)  return false;
      return true;
    }).toList();

    res.sort((a, b) {
      final fa = DateTime.tryParse(a['fecha_compra'] ?? '') ?? DateTime(2000);
      final fb = DateTime.tryParse(b['fecha_compra'] ?? '') ?? DateTime(2000);
      return fb.compareTo(fa);
    });
    setState(() => clientesFiltrados = res);
  }

  String _identidad(Map c) {
    final n = (c['nombre_fb'] ?? '').toString().trim();
    final e = (c['email']    ?? '').toString().trim();
    final t = (c['telefono'] ?? '').toString().trim();
    if (n.isNotEmpty) return n;
    if (e.isNotEmpty) return e;
    if (t.isNotEmpty) return t;
    return 'Sin identificador';
  }

  String _subtitulo(Map c) {
    final n = (c['nombre_fb'] ?? '').toString().trim();
    final e = (c['email']    ?? '').toString().trim();
    final t = (c['telefono'] ?? '').toString().trim();
    List<String> extras = [];
    if (n.isNotEmpty && e.isNotEmpty) extras.add(e);
    if (n.isNotEmpty && t.isNotEmpty) extras.add(t);
    if (n.isEmpty && e.isNotEmpty && t.isNotEmpty) extras.add(t);
    return extras.join(' · ');
  }

  List _historialCompleto(Map c) {
    final email  = (c['email']    ?? '').toString().trim();
    final tel    = (c['telefono'] ?? '').toString().trim();
    final nombre = (c['nombre_fb']?? '').toString().trim();
    List hist = clientes.where((x) {
      if (email.isNotEmpty  && (x['email']    ?? '').toString().trim() == email)  return true;
      if (tel.isNotEmpty && tel.length > 5 && (x['telefono'] ?? '').toString().trim() == tel) return true;
      if (nombre.isNotEmpty && nombre.length > 3 && (x['nombre_fb'] ?? '').toString().trim() == nombre) return true;
      return false;
    }).toList();
    hist.sort((a, b) {
      final fa = DateTime.tryParse(a['fecha_compra'] ?? '') ?? DateTime(2000);
      final fb = DateTime.tryParse(b['fecha_compra'] ?? '') ?? DateTime(2000);
      return fb.compareTo(fa);
    });
    return hist;
  }

  void verHistorialCliente(Map c) {
    final historial   = _historialCompleto(c);
    final identidad   = _identidad(c);
    final totalPagado = historial.fold<double>(0, (s, x) => s + (x['monto'] ?? 0).toDouble());

    showDialog(context: context,
      builder: (_) => Dialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(identidad,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                overflow: TextOverflow.ellipsis)),
              IconButton(onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white54, size: 20)),
            ]),
            Text("${historial.length} compras · Total: \$${totalPagado.toStringAsFixed(0)}",
              style: const TextStyle(color: kGreen, fontSize: 12)),
            const Divider(color: Colors.white12, height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: historial.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 10),
                itemBuilder: (_, i) {
                  final x     = historial[i];
                  final fecha = DateTime.tryParse(x['fecha_compra'] ?? '') ?? DateTime.now();
                  final venc  = _fechaVencimiento(x);
                  final vencido = estaVencido(x);
                  return Row(children: [
                    Container(width: 3, height: 48,
                      decoration: BoxDecoration(
                        color: vencido ? kOrange : kGreen,
                        borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(x['paquete'] ?? '',
                        style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                      Text("${DateFormat('dd/MM/yyyy').format(fecha)} → ${DateFormat('dd/MM/yyyy').format(venc)}",
                        style: const TextStyle(fontSize: 11, color: Colors.white54)),
                      if ((x['nota'] ?? '').toString().isNotEmpty)
                        Text("📝 ${x['nota']}", style: const TextStyle(fontSize: 10, color: Colors.white38)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text("\$${x['monto']}",
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(vencido ? "VENC." : "ACTIVO",
                        style: TextStyle(color: vencido ? kOrange : kGreen, fontSize: 9, fontWeight: FontWeight.bold)),
                    ]),
                  ]);
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> toggleNotificacion(Map c) async {
    final nuevo = !(c['notificacion_enviada'] ?? false);
    await supabase.from('ventas').update({'notificacion_enviada': nuevo}).eq('id', c['id']);
    cargarClientes();
  }

  void eliminarCliente(dynamic id) async {
    await supabase.from('ventas').delete().eq('id', id);
    cargarClientes();
  }

  void exportarCorreos() {
    final activos = clientes.where((c) => !estaVencido(c) && (c['email'] ?? '').toString().trim().isNotEmpty).toList();
    final correos = activos.map((c) => c['email'].toString().trim()).join('\n');
    if (correos.isEmpty) { _snack('No hay correos de clientes activos'); return; }
    Clipboard.setData(ClipboardData(text: correos));
    _snack('${activos.length} correos copiados ✓');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: kCard2, duration: const Duration(seconds: 3)));
  }

  // ─── FORMULARIOS ─────────────────────────────────────────
  void mostrarFormularioAgregar() {
    final nombre   = TextEditingController();
    final email    = TextEditingController();
    final telefono = TextEditingController();
    final paquete  = TextEditingController();
    final meses    = TextEditingController(text: '1');
    final monto    = TextEditingController();
    final nota     = TextEditingController();
    String canal   = 'messenger';

    showDialog(context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: kCard,
          title: const Text("Nueva venta", style: TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(child: Column(children: [
            _field(nombre,   "Nombre (FB)"),
            _field(email,    "Email",           type: TextInputType.emailAddress),
            _field(telefono, "Teléfono",        type: TextInputType.phone),
            _field(paquete,  "Paquete"),
            _field(meses,    "Meses de acceso", type: TextInputType.number),
            _field(monto,    "Monto (\$)",      type: TextInputType.number),
            _field(nota,     "Nota (opcional)"),
            const SizedBox(height: 10),
            Row(children: [
              const Text("Canal: ", style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 8),
              _canalBtn('messenger', canal, () => setS(() => canal = 'messenger')),
              const SizedBox(width: 8),
              _canalBtn('whatsapp',  canal, () => setS(() => canal = 'whatsapp')),
            ]),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kRed),
              onPressed: () async {
                await supabase.from('ventas').insert({
                  "nombre_fb": nombre.text, "email": email.text,
                  "telefono": telefono.text, "paquete": paquete.text,
                  "meses": int.tryParse(meses.text) ?? 1,
                  "monto": double.tryParse(monto.text) ?? 0,
                  "fecha_compra": DateTime.now().toIso8601String(),
                  "canal_contacto": canal, "nota": nota.text,
                  "notificacion_enviada": false,
                });
                Navigator.pop(ctx);
                cargarClientes();
              },
              child: const Text("Guardar"),
            ),
          ],
        ),
      ),
    );
  }

  void mostrarFormularioEditar(Map c) {
    final nombre   = TextEditingController(text: c['nombre_fb'] ?? '');
    final email    = TextEditingController(text: c['email']     ?? '');
    final telefono = TextEditingController(text: c['telefono']  ?? '');
    final paquete  = TextEditingController(text: c['paquete']   ?? '');
    final meses    = TextEditingController(text: (c['meses']    ?? 1).toString());
    final monto    = TextEditingController(text: (c['monto']    ?? 0).toString());
    final nota     = TextEditingController(text: c['nota']      ?? '');
    String canal   = c['canal_contacto'] ?? 'messenger';

    showDialog(context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: kCard,
          title: const Text("Editar venta", style: TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(child: Column(children: [
            _field(nombre,   "Nombre (FB)"),
            _field(email,    "Email",           type: TextInputType.emailAddress),
            _field(telefono, "Teléfono",        type: TextInputType.phone),
            _field(paquete,  "Paquete"),
            _field(meses,    "Meses de acceso", type: TextInputType.number),
            _field(monto,    "Monto (\$)",      type: TextInputType.number),
            _field(nota,     "Nota"),
            const SizedBox(height: 10),
            Row(children: [
              const Text("Canal: ", style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 8),
              _canalBtn('messenger', canal, () => setS(() => canal = 'messenger')),
              const SizedBox(width: 8),
              _canalBtn('whatsapp',  canal, () => setS(() => canal = 'whatsapp')),
            ]),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kRed),
              onPressed: () async {
                await supabase.from('ventas').update({
                  "nombre_fb": nombre.text, "email": email.text,
                  "telefono": telefono.text, "paquete": paquete.text,
                  "meses": int.tryParse(meses.text) ?? 1,
                  "monto": double.tryParse(monto.text) ?? 0,
                  "canal_contacto": canal, "nota": nota.text,
                }).eq('id', c['id']);
                Navigator.pop(ctx);
                cargarClientes();
              },
              child: const Text("Guardar"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl, keyboardType: type,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: kGreen)),
        ),
      ),
    );
  }

  Widget _canalBtn(String val, String actual, VoidCallback onTap) {
    final selected = val == actual;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? (val == 'whatsapp' ? const Color(0xFF25D366) : const Color(0xFF0084FF)) : kCard2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.transparent : Colors.white24),
        ),
        child: Text(val == 'whatsapp' ? '📱 WhatsApp' : '💬 Messenger',
          style: TextStyle(color: selected ? Colors.white : Colors.white54, fontSize: 12)),
      ),
    );
  }

  // ─── BUILD ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kCard,
        elevation: 0,
        title: Row(children: [
          Image.asset('assets/images/logo.png', height: 26),
          const SizedBox(width: 8),
          const Text("Remix Pro DJ", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.email_outlined, color: kGreen, size: 20),
            tooltip: 'Exportar correos activos',
            onPressed: exportarCorreos,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kRed,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.list_alt, size: 16),       text: "Ventas"),
            Tab(icon: Icon(Icons.bar_chart, size: 16),      text: "Dashboard"),
            Tab(icon: Icon(Icons.people_outline, size: 16), text: "Clientes"),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kRed, mini: true,
        onPressed: mostrarFormularioAgregar,
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_tabVentas(), _tabDashboard(), _tabClientes()],
      ),
    );
  }

  // ─── TAB VENTAS ──────────────────────────────────────────
  Widget _tabVentas() {
    // Conteos sobre el filtro actual sin filtro de estado
    final sinFiltroEstado = clientes.where((c) {
      final texto   = buscador.text.toLowerCase();
      final nombre  = (c['nombre_fb'] ?? '').toLowerCase();
      final email   = (c['email']    ?? '').toLowerCase();
      final tel     = (c['telefono'] ?? '').toLowerCase();
      final paquete = (c['paquete']  ?? '');
      final fecha   = DateTime.tryParse(c['fecha_compra'] ?? '') ?? DateTime.now();
      if (texto.isNotEmpty && !nombre.contains(texto) && !email.contains(texto) && !tel.contains(texto)) return false;
      if (filtroPaquete != "Todos" && paquete != filtroPaquete) return false;
      if (filtroAnio != null && fecha.year  != filtroAnio) return false;
      if (filtroMes  != null && fecha.month != filtroMes)  return false;
      return true;
    }).toList();

    final cntVencidos = sinFiltroEstado.where((c) =>  estaVencido(c)).length;
    final cntActivos  = sinFiltroEstado.where((c) => !estaVencido(c)).length;
    final acumFiltro  = clientesFiltrados.fold<double>(0, (s, c) => s + (c['monto'] ?? 0).toDouble());

    return Column(children: [

      // ── Buscador compacto ──
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
        child: SizedBox(
          height: 36,
          child: TextField(
            controller: buscador,
            onChanged: (_) => aplicarFiltros(),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: "Buscar...",
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              filled: true, fillColor: kCard2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
        ),
      ),

      // ── Fila de filtros unificada ──
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(children: [

          // ── Botón Todos ──
          _btnFiltro(
            label: "Todos",
            count: sinFiltroEstado.length,
            color: Colors.white54,
            selected: filtroEstado == "Todos",
            onTap: () { setState(() => filtroEstado = "Todos"); aplicarFiltros(); },
          ),
          const SizedBox(width: 6),

          // ── Botón Vencidos (naranja) con conteo ──
          _btnFiltro(
            label: "Vencidos",
            count: cntVencidos,
            color: kOrange,
            selected: filtroEstado == "Vencidos",
            onTap: () { setState(() => filtroEstado = "Vencidos"); aplicarFiltros(); },
          ),
          const SizedBox(width: 6),

          // ── Botón Activos (verde) con conteo ──
          _btnFiltro(
            label: "Activos",
            count: cntActivos,
            color: kGreen,
            selected: filtroEstado == "Activos",
            onTap: () { setState(() => filtroEstado = "Activos"); aplicarFiltros(); },
          ),

          const Spacer(),

          // ── Mes ──
          _chipFiltro(
            label: filtroMes == null ? "Mes" : mesesTexto[filtroMes! - 1].substring(0, 3),
            active: filtroMes != null,
            color: kBlue,
            onTap: _showMesPicker,
          ),
          const SizedBox(width: 5),

          // ── Paquete ──
          _chipFiltro(
            label: filtroPaquete == "Todos" ? "Paquete" :
              (filtroPaquete.length > 10 ? "${filtroPaquete.substring(0, 10)}…" : filtroPaquete),
            active: filtroPaquete != "Todos",
            color: kBlue,
            onTap: _showPaquetePicker,
          ),
        ]),
      ),

      // ── Años ──
      SizedBox(
        height: 34,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: listaAnios.map((anio) => GestureDetector(
            onTap: () { setState(() => filtroAnio = anio); aplicarFiltros(); },
            child: Container(
              margin: const EdgeInsets.only(right: 6, top: 3, bottom: 3),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: filtroAnio == anio ? kGreen : kCard2,
                borderRadius: BorderRadius.circular(16)),
              child: Center(child: Text(anio.toString(),
                style: TextStyle(
                  color: filtroAnio == anio ? Colors.black : Colors.white70,
                  fontWeight: FontWeight.bold, fontSize: 12))),
            ),
          )).toList(),
        ),
      ),

      // ── Resumen compacto ──
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Row(children: [
          Text("${clientesFiltrados.length} registros · \$${acumFiltro.toStringAsFixed(0)}",
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
      ),

      // ── Lista ──
      Expanded(
        child: ListView.builder(
          itemCount: clientesFiltrados.length,
          padding: const EdgeInsets.only(bottom: 70),
          itemBuilder: (_, i) => _buildCard(clientesFiltrados[i]),
        ),
      ),
    ]);
  }

  // Botón filtro principal con label + conteo
  Widget _btnFiltro({
    required String label,
    required int count,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.2) : kCard2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.white12, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(
            color: selected ? color : Colors.white38,
            fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: selected ? color : color.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10)),
            child: Text("$count", style: TextStyle(
              color: selected ? Colors.black : color,
              fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }

  // Chip secundario para Mes y Paquete
  Widget _chipFiltro({
    required String label,
    required bool active,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.15) : kCard2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? color : Colors.white12, width: 1.2),
        ),
        child: Text(label, style: TextStyle(
          color: active ? color : Colors.white38, fontSize: 11)),
      ),
    );
  }

  void _showMesPicker() {
    showModalBottomSheet(context: context, backgroundColor: kCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          title: const Text("Todos los meses", style: TextStyle(color: Colors.white)),
          onTap: () { setState(() => filtroMes = null); aplicarFiltros(); Navigator.pop(context); },
        ),
        ...List.generate(12, (i) => ListTile(
          title: Text(mesesTexto[i], style: const TextStyle(color: Colors.white)),
          tileColor: filtroMes == i + 1 ? kGreen.withOpacity(0.1) : null,
          onTap: () { setState(() => filtroMes = i + 1); aplicarFiltros(); Navigator.pop(context); },
        )),
      ]),
    );
  }

  void _showPaquetePicker() {
    showModalBottomSheet(context: context, backgroundColor: kCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => ListView(shrinkWrap: true,
        children: paquetes.map((p) => ListTile(
          title: Text(p, style: const TextStyle(color: Colors.white, fontSize: 13)),
          tileColor: filtroPaquete == p ? kBlue.withOpacity(0.1) : null,
          onTap: () { setState(() => filtroPaquete = p); aplicarFiltros(); Navigator.pop(context); },
        )).toList(),
      ),
    );
  }

  // ─── CARD ────────────────────────────────────────────────
  Widget _buildCard(Map c) {
    final fecha   = DateTime.tryParse(c['fecha_compra'] ?? '') ?? DateTime.now();
    final venc    = _fechaVencimiento(c);
    final vencido = estaVencido(c);
    final dias    = diasParaVencer(c);
    final notif   = c['notificacion_enviada'] ?? false;
    final canal   = c['canal_contacto'] ?? 'messenger';
    final nota    = (c['nota'] ?? '').toString();

    Color borderColor = vencido ? kOrange : kGreen;
    Color bgColor     = vencido ? const Color(0xFF150800) : kCard;
    if (!vencido && dias <= 7) { borderColor = Colors.yellow; bgColor = const Color(0xFF151500); }

    return GestureDetector(
      onTap: () => verHistorialCliente(c),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor.withOpacity(0.5), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(canal == 'whatsapp' ? "📱 " : "💬 ", style: const TextStyle(fontSize: 11)),
                Expanded(child: Text(_identidad(c),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  overflow: TextOverflow.ellipsis)),
              ]),
              if (_subtitulo(c).isNotEmpty)
                Text(_subtitulo(c), style: const TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 2),
              Text(c['paquete'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11)),
              Text("\$${c['monto']}", style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
              Row(children: [
                Text("${DateFormat('dd/MM/yy').format(fecha)} → ",
                  style: const TextStyle(color: kGreen, fontSize: 10)),
                Text(DateFormat('dd/MM/yy').format(venc),
                  style: TextStyle(color: vencido ? kOrange : Colors.white38, fontSize: 10,
                    fontWeight: vencido ? FontWeight.bold : FontWeight.normal)),
              ]),
              if (nota.isNotEmpty)
                Text("📝 $nota", style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ])),
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: vencido ? kOrange.withOpacity(0.15) : kGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6)),
                child: Text(
                  _tiempoRestante(vencido, dias, c['meses']),
                  style: TextStyle(color: vencido ? kOrange : (dias <= 7 ? Colors.yellow : kGreen), fontSize: 9, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => toggleNotificacion(c),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: notif ? const Color(0xFF0084FF).withOpacity(0.2) : kCard2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: notif ? const Color(0xFF0084FF) : Colors.white12)),
                  child: Text(notif ? "✉️" : "📨", style: const TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 4),
              Row(children: [
                IconButton(icon: const Icon(Icons.edit, size: 14, color: Colors.white38),
                  onPressed: () => mostrarFormularioEditar(c),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                const SizedBox(width: 4),
                IconButton(icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                  onPressed: () async {
                    final ok = await showDialog<bool>(context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: kCard,
                        title: const Text("Eliminar"),
                        content: const Text("¿Eliminar este registro?"),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
                          TextButton(onPressed: () => Navigator.pop(context, true),
                            child: const Text("Eliminar", style: TextStyle(color: kRed))),
                        ],
                      ));
                    if (ok == true) eliminarCliente(c['id']);
                  },
                  padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ]),
            ]),
          ]),
        ),
      ),
    );
  }

  // ─── TAB DASHBOARD ───────────────────────────────────────
  Widget _tabDashboard() {
    final now = DateTime.now();
    final mesActual = mesesTexto[now.month - 1];
    final pct = ingresosMes / metaMes;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _acumCard("Acum. $mesActual", ingresosMes,  kGreen, Icons.calendar_today),
          const SizedBox(width: 8),
          _acumCard("Acum. ${now.year}", ingresosAnio, kBlue,  Icons.bar_chart),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _statCard("Activos",  totalActivos.toString(),  kGreen,  Icons.check_circle_outline),
          const SizedBox(width: 8),
          _statCard("Vencidos", totalVencidos.toString(), kOrange, Icons.warning_amber_outlined),
          const SizedBox(width: 8),
          _statCard("Total", (totalActivos + totalVencidos).toString(), Colors.white38, Icons.people_outline),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text("Meta $mesActual", style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              GestureDetector(onTap: _editarMeta, child: const Icon(Icons.edit, size: 14, color: Colors.white38)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Text("\$${ingresosMes.toStringAsFixed(0)}",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(" / \$${metaMes.toStringAsFixed(0)}",
                style: const TextStyle(fontSize: 12, color: Colors.white38)),
              const Spacer(),
              Text(pct >= 1 ? "✅ SUPERADA" : "${(pct * 100).toStringAsFixed(0)}%",
                style: TextStyle(color: pct >= 1 ? kGreen : kOrange, fontWeight: FontWeight.bold, fontSize: 12)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct.clamp(0.0, 1.0), minHeight: 7,
                backgroundColor: kCard2,
                valueColor: AlwaysStoppedAnimation(pct >= 1 ? kGreen : kOrange)),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        const Text("Ingresos por mes", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          height: 180, padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(12)),
          child: _graficaBarras(),
        ),
        const SizedBox(height: 10),
        Row(children: [
          const Text("Vencidos sin avisar", style: TextStyle(color: kOrange, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: kOrange.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
            child: Text(
              "${clientes.where((c) => estaVencido(c) && !(c['notificacion_enviada'] ?? false)).length}",
              style: const TextStyle(color: kOrange, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 6),
        ...clientes.where((c) => estaVencido(c) && !(c['notificacion_enviada'] ?? false)).take(15).map((c) =>
          Container(
            margin: const EdgeInsets.only(bottom: 5),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kOrange.withOpacity(0.3))),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_identidad(c), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text(c['paquete'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 10)),
              ])),
              Text((c['canal_contacto'] ?? '') == 'whatsapp' ? "📱" : "💬"),
              const SizedBox(width: 8),
              GestureDetector(onTap: () => toggleNotificacion(c),
                child: const Text("📨", style: TextStyle(fontSize: 20))),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _acumCard(String label, double valor, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3))),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
            Text("\$${valor.toStringAsFixed(0)}",
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          ])),
        ]),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ]),
      ),
    );
  }

  Widget _graficaBarras() {
    final now = DateTime.now();
    final mesesOrden = mesesTexto.take(now.month).toList();
    final maxVal = ingresosPorMes.values.isEmpty ? 1.0 : ingresosPorMes.values.reduce((a, b) => a > b ? a : b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: mesesOrden.map((mes) {
        final val = ingresosPorMes[mes] ?? 0;
        final ratio = maxVal > 0 ? val / maxVal : 0.0;
        final esMesActual = mes == mesesTexto[now.month - 1];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (val > 0) Text("\$${(val / 1000).toStringAsFixed(0)}k",
                style: TextStyle(color: esMesActual ? kGreen : Colors.white38, fontSize: 7)),
              const SizedBox(height: 2),
              Container(
                height: (ratio * 120).clamp(4.0, 120.0),
                decoration: BoxDecoration(
                  color: esMesActual ? kGreen : kRed.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 3),
              Text(mes.substring(0, 3),
                style: TextStyle(color: esMesActual ? kGreen : Colors.white38, fontSize: 7,
                  fontWeight: esMesActual ? FontWeight.bold : FontWeight.normal)),
            ]),
          ),
        );
      }).toList(),
    );
  }

  void _editarMeta() {
    final ctrl = TextEditingController(text: metaMes.toStringAsFixed(0));
    showDialog(context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        title: const Text("Meta mensual"),
        content: TextField(controller: ctrl, keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: "Meta en \$",
            labelStyle: TextStyle(color: Colors.white54))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kRed),
            onPressed: () { setState(() => metaMes = double.tryParse(ctrl.text) ?? metaMes); Navigator.pop(context); },
            child: const Text("Guardar")),
        ],
      ));
  }

  // ─── TAB CLIENTES ────────────────────────────────────────
  Widget _tabClientes() {
    final textoC = buscadorClientes.text.toLowerCase().replaceAll(' ', '');

    Map<String, List> grupos = {};
    for (var c in clientes) {
      final email = (c['email']    ?? '').toString().trim();
      final tel   = (c['telefono'] ?? '').toString().trim();
      final nom   = (c['nombre_fb']?? '').toString().trim();
      String key  = email.isNotEmpty ? email : (tel.isNotEmpty && tel.length > 5 ? tel : nom);
      if (key.isEmpty) key = 'Sin identificador';
      grupos.putIfAbsent(key, () => []);
      grupos[key]!.add(c);
    }

    List<MapEntry<String, List>> lista = grupos.entries.toList();
    lista.sort((a, b) => b.value.length.compareTo(a.value.length));

    if (textoC.isNotEmpty) {
      lista = lista.where((e) {
        final rep = e.value.first;
        final telC = (rep['telefono'] ?? '').toString().toLowerCase().replaceAll(' ', '');
        return _identidad(rep).toLowerCase().contains(textoC) ||
               (rep['email'] ?? '').toString().toLowerCase().contains(textoC) ||
               telC.contains(textoC);
      }).toList();
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
        child: SizedBox(
          height: 36,
          child: TextField(
            controller: buscadorClientes,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: "Buscar cliente...",
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              filled: true, fillColor: kCard2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Row(children: [
          Text("${lista.length} clientes únicos",
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 80),
          itemCount: lista.length,
          itemBuilder: (_, i) {
            final entry   = lista[i];
            final compras = entry.value;
            compras.sort((a, b) {
              final fa = DateTime.tryParse(a['fecha_compra'] ?? '') ?? DateTime(2000);
              final fb = DateTime.tryParse(b['fecha_compra'] ?? '') ?? DateTime(2000);
              return fb.compareTo(fa);
            });
            final ultima  = compras.first;
            final vencido = estaVencido(ultima);
            final total   = compras.fold<double>(0, (s, c) => s + (c['monto'] ?? 0).toDouble());

            return GestureDetector(
              onTap: () => verHistorialCliente(ultima),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: vencido ? kOrange.withOpacity(0.3) : kGreen.withOpacity(0.3))),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: vencido ? kOrange.withOpacity(0.15) : kGreen.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: vencido ? kOrange : kGreen, width: 1.5)),
                    child: Center(child: Text(
                      _identidad(ultima).isNotEmpty ? _identidad(ultima)[0].toUpperCase() : '?',
                      style: TextStyle(color: vencido ? kOrange : kGreen, fontWeight: FontWeight.bold, fontSize: 15))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_identidad(ultima),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      overflow: TextOverflow.ellipsis),
                    if (_subtitulo(ultima).isNotEmpty)
                      Text(_subtitulo(ultima), style: const TextStyle(color: Colors.white54, fontSize: 10)),
                    Text("Último: ${ultima['paquete'] ?? ''}",
                      style: const TextStyle(color: Colors.white38, fontSize: 10), overflow: TextOverflow.ellipsis),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (compras.length >= 3 ? kGreen : Colors.white38).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8)),
                      child: Text("${compras.length} compras",
                        style: TextStyle(
                          color: compras.length >= 3 ? kGreen : Colors.white38,
                          fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 3),
                    Text("\$${total.toStringAsFixed(0)}",
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(vencido ? "VENCIDO" : "ACTIVO",
                      style: TextStyle(color: vencido ? kOrange : kGreen, fontSize: 9, fontWeight: FontWeight.bold)),
                  ]),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}