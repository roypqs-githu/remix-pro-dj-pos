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
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF2D55),
          secondary: Color(0xFF00E676),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// ─── COLORES ───────────────────────────────────────────────
const kRed = Color(0xFFFF2D55);
const kGreen = Color(0xFF00E676);
const kOrange = Color(0xFFFF6D00);
const kBg = Color(0xFF0A0A0A);
const kCard = Color(0xFF141414);
const kCard2 = Color(0xFF1C1C1C);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  List clientes = [];
  List clientesFiltrados = [];

  String filtroEstado = "Todos";
  String filtroPaquete = "Todos";
  int? filtroAnio;
  int? filtroMes;

  List<String> paquetes = ["Todos"];
  List<int> listaAnios = [];

  final buscador = TextEditingController();
  Timer? autoRefresh;

  late TabController _tabController;

  // Stats para dashboard
  int totalActivos = 0;
  int totalVencidos = 0;
  double ingresosMes = 0;
  double metaMes = 18000;
  Map<String, double> ingresosPorMes = {};

  final mesesTexto = [
    "Enero",
    "Febrero",
    "Marzo",
    "Abril",
    "Mayo",
    "Junio",
    "Julio",
    "Agosto",
    "Septiembre",
    "Octubre",
    "Noviembre",
    "Diciembre"
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    filtroAnio = now.year;
    filtroMes = null;
    cargarClientes();
    autoRefresh =
        Timer.periodic(const Duration(seconds: 30), (_) => cargarClientes());
  }

  @override
  void dispose() {
    autoRefresh?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> cargarClientes() async {
    final data = await supabase
        .from('ventas')
        .select()
        .order('fecha_compra', ascending: false);

    Set<String> listaPaquetes = {"Todos"};
    Set<int> anios = {};
    int activos = 0, vencidos = 0;
    double ingresosMesActual = 0;
    Map<String, double> porMes = {};
    final now = DateTime.now();

    for (var c in data) {
      final fecha = DateTime.tryParse(c['fecha_compra'] ?? '') ?? now;
      anios.add(fecha.year);
      if (c['paquete'] != null && c['paquete'] != "") {
        listaPaquetes.add(c['paquete']);
      }

      final venc = _fechaVencimiento(c);
      if (now.isAfter(venc)) {
        vencidos++;
      } else {
        activos++;
      }

      // Ingresos por mes (año actual)
      if (fecha.year == now.year) {
        final key = mesesTexto[fecha.month - 1];
        porMes[key] = (porMes[key] ?? 0) + (c['monto'] ?? 0).toDouble();
        if (fecha.month == now.month) {
          ingresosMesActual += (c['monto'] ?? 0).toDouble();
        }
      }
    }

    setState(() {
      clientes = data;
      paquetes = listaPaquetes.toList();
      listaAnios = anios.toList()..sort((b, a) => a.compareTo(b));
      totalActivos = activos;
      totalVencidos = vencidos;
      ingresosMes = ingresosMesActual;
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

  // Días para vencer (negativo = ya venció)
  int diasParaVencer(Map c) {
    final venc = _fechaVencimiento(c);
    return venc.difference(DateTime.now()).inDays;
  }

  void aplicarFiltros() {
    final texto = buscador.text.toLowerCase();
    final res = clientes.where((c) {
      final nombre = (c['nombre_fb'] ?? '').toLowerCase();
      final email = (c['email'] ?? '').toLowerCase();
      final tel = (c['telefono'] ?? '').toLowerCase();
      final paquete = (c['paquete'] ?? '');
      final fecha =
          DateTime.tryParse(c['fecha_compra'] ?? '') ?? DateTime.now();
      final vencido = estaVencido(c);

      final coincide = texto.isEmpty ||
          nombre.contains(texto) ||
          email.contains(texto) ||
          tel.contains(texto);

      if (filtroEstado == "Vencidos" && !vencido) return false;
      if (filtroEstado == "Activos" && vencido) return false;
      if (filtroPaquete != "Todos" && paquete != filtroPaquete) return false;
      if (filtroAnio != null && fecha.year != filtroAnio) return false;
      if (filtroMes != null && fecha.month != filtroMes) return false;
      return coincide;
    }).toList();

    // Vencidos primero
    res.sort((a, b) {
      final aVenc = estaVencido(a);
      final bVenc = estaVencido(b);
      if (aVenc && !bVenc) return -1;
      if (!aVenc && bVenc) return 1;
      return 0;
    });

    setState(() => clientesFiltrados = res);
  }

  Future<void> toggleNotificacion(Map c) async {
    final nuevo = !(c['notificacion_enviada'] ?? false);
    await supabase
        .from('ventas')
        .update({'notificacion_enviada': nuevo}).eq('id', c['id']);
    cargarClientes();
  }

  void eliminarCliente(dynamic id) async {
    await supabase.from('ventas').delete().eq('id', id);
    cargarClientes();
  }

  void exportarCorreos() {
    final activos = clientes
        .where((c) =>
            !estaVencido(c) && (c['email'] ?? '').toString().trim().isNotEmpty)
        .toList();
    final correos = activos.map((c) => c['email'].toString().trim()).join('\n');
    if (correos.isEmpty) {
      _showSnack('No hay correos de clientes activos');
      return;
    }
    Clipboard.setData(ClipboardData(text: correos));
    _showSnack('${activos.length} correos copiados al portapapeles ✓');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: kCard2,
          duration: const Duration(seconds: 3)),
    );
  }

  // ─── FORMULARIO AGREGAR ──────────────────────────────────
  void mostrarFormularioAgregar() {
    final nombre = TextEditingController();
    final email = TextEditingController();
    final telefono = TextEditingController();
    final paquete = TextEditingController();
    final meses = TextEditingController(text: '1');
    final monto = TextEditingController();
    final nota = TextEditingController();
    String canal = 'messenger';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: kCard,
          title: const Text("Nueva venta",
              style: TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(children: [
              _field(nombre, "Nombre (FB)"),
              _field(email, "Email", type: TextInputType.emailAddress),
              _field(telefono, "Teléfono", type: TextInputType.phone),
              _field(paquete, "Paquete"),
              _field(meses, "Meses de acceso", type: TextInputType.number),
              _field(monto, "Monto (\$)", type: TextInputType.number),
              _field(nota, "Nota (opcional)"),
              const SizedBox(height: 10),
              Row(children: [
                const Text("Canal: ", style: TextStyle(color: Colors.white70)),
                const SizedBox(width: 8),
                _canalBtn(
                    'messenger', canal, () => setS(() => canal = 'messenger')),
                const SizedBox(width: 8),
                _canalBtn(
                    'whatsapp', canal, () => setS(() => canal = 'whatsapp')),
              ]),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancelar")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kRed),
              onPressed: () async {
                await supabase.from('ventas').insert({
                  "nombre_fb": nombre.text,
                  "email": email.text,
                  "telefono": telefono.text,
                  "paquete": paquete.text,
                  "meses": int.tryParse(meses.text) ?? 1,
                  "monto": double.tryParse(monto.text) ?? 0,
                  "fecha_compra": DateTime.now().toIso8601String(),
                  "canal_contacto": canal,
                  "nota": nota.text,
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

  // ─── FORMULARIO EDITAR ───────────────────────────────────
  void mostrarFormularioEditar(Map c) {
    final nombre = TextEditingController(text: c['nombre_fb'] ?? '');
    final email = TextEditingController(text: c['email'] ?? '');
    final telefono = TextEditingController(text: c['telefono'] ?? '');
    final paquete = TextEditingController(text: c['paquete'] ?? '');
    final meses = TextEditingController(text: (c['meses'] ?? 1).toString());
    final monto = TextEditingController(text: (c['monto'] ?? 0).toString());
    final nota = TextEditingController(text: c['nota'] ?? '');
    String canal = c['canal_contacto'] ?? 'messenger';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: kCard,
          title: const Text("Editar venta",
              style: TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(children: [
              _field(nombre, "Nombre (FB)"),
              _field(email, "Email", type: TextInputType.emailAddress),
              _field(telefono, "Teléfono", type: TextInputType.phone),
              _field(paquete, "Paquete"),
              _field(meses, "Meses de acceso", type: TextInputType.number),
              _field(monto, "Monto (\$)", type: TextInputType.number),
              _field(nota, "Nota"),
              const SizedBox(height: 10),
              Row(children: [
                const Text("Canal: ", style: TextStyle(color: Colors.white70)),
                const SizedBox(width: 8),
                _canalBtn(
                    'messenger', canal, () => setS(() => canal = 'messenger')),
                const SizedBox(width: 8),
                _canalBtn(
                    'whatsapp', canal, () => setS(() => canal = 'whatsapp')),
              ]),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancelar")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kRed),
              onPressed: () async {
                await supabase.from('ventas').update({
                  "nombre_fb": nombre.text,
                  "email": email.text,
                  "telefono": telefono.text,
                  "paquete": paquete.text,
                  "meses": int.tryParse(meses.text) ?? 1,
                  "monto": double.tryParse(monto.text) ?? 0,
                  "canal_contacto": canal,
                  "nota": nota.text,
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

  Widget _field(TextEditingController ctrl, String label,
      {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24)),
          focusedBorder:
              const UnderlineInputBorder(borderSide: BorderSide(color: kGreen)),
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
          color: selected
              ? (val == 'whatsapp'
                  ? const Color(0xFF25D366)
                  : const Color(0xFF0084FF))
              : kCard2,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: selected ? Colors.transparent : Colors.white24),
        ),
        child: Text(val == 'whatsapp' ? '📱 WhatsApp' : '💬 Messenger',
            style: TextStyle(
                color: selected ? Colors.white : Colors.white54, fontSize: 12)),
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
          Image.asset('assets/images/logo.png', height: 28),
          const SizedBox(width: 10),
          const Text("Remix Pro DJ POS",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.email_outlined, color: kGreen),
            tooltip: 'Exportar correos activos',
            onPressed: exportarCorreos,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kRed,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt), text: "Ventas"),
            Tab(icon: Icon(Icons.bar_chart), text: "Dashboard"),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kRed,
        onPressed: mostrarFormularioAgregar,
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _tabVentas(),
          _tabDashboard(),
        ],
      ),
    );
  }

  // ─── TAB VENTAS ──────────────────────────────────────────
  Widget _tabVentas() {
    return Column(children: [
      // Buscador
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
        child: TextField(
          controller: buscador,
          onChanged: (_) => aplicarFiltros(),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Buscar cliente...",
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.search, color: Colors.white38),
            filled: true,
            fillColor: kCard2,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
      ),
      // Filtros
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _dropdownCompacto(
                "Estado", filtroEstado, ["Todos", "Activos", "Vencidos"], (v) {
              setState(() => filtroEstado = v);
              aplicarFiltros();
            }),
            _dropdownMes("Mes", filtroMes, (v) {
              setState(() => filtroMes = v);
              aplicarFiltros();
            }),
            _dropdownCompacto(
                "Paquete",
                filtroPaquete,
                paquetes.length > 8
                    ? ["Todos", ...paquetes.skip(1).take(7)]
                    : paquetes, (v) {
              setState(() => filtroPaquete = v);
              aplicarFiltros();
            }),
          ],
        ),
      ),
      // Años
      SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          children: listaAnios
              .map((anio) => GestureDetector(
                    onTap: () {
                      setState(() => filtroAnio = anio);
                      aplicarFiltros();
                    },
                    child: Container(
                      margin:
                          const EdgeInsets.only(right: 6, top: 4, bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: filtroAnio == anio ? kGreen : kCard2,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                          child: Text(anio.toString(),
                              style: TextStyle(
                                  color: filtroAnio == anio
                                      ? Colors.black
                                      : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13))),
                    ),
                  ))
              .toList(),
        ),
      ),
      // Contador
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(children: [
          Text("${clientesFiltrados.length} registros",
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const Spacer(),
          _badge(
              "${clientesFiltrados.where((c) => estaVencido(c)).length} vencidos",
              kOrange),
          const SizedBox(width: 6),
          _badge(
              "${clientesFiltrados.where((c) => !estaVencido(c)).length} activos",
              kGreen),
        ]),
      ),
      // Lista
      Expanded(
        child: ListView.builder(
          itemCount: clientesFiltrados.length,
          padding: const EdgeInsets.only(bottom: 80),
          itemBuilder: (_, i) => _buildCard(clientesFiltrados[i]),
        ),
      ),
    ]);
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCard(Map c) {
    final fecha = DateTime.tryParse(c['fecha_compra'] ?? '') ?? DateTime.now();
    final venc = _fechaVencimiento(c);
    final vencido = estaVencido(c);
    final dias = diasParaVencer(c);
    final notifEnviada = c['notificacion_enviada'] ?? false;
    final canal = c['canal_contacto'] ?? 'messenger';
    final nota = c['nota'] ?? '';

    Color borderColor = vencido ? kOrange : kGreen;
    Color bgColor = vencido ? const Color(0xFF1A0800) : kCard;

    // Próximo a vencer (menos de 7 días)
    if (!vencido && dias <= 7) {
      borderColor = Colors.yellow;
      bgColor = const Color(0xFF1A1A00);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withOpacity(0.6), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Nombre + canal
              Row(children: [
                if (canal == 'whatsapp')
                  const Text("📱 ", style: TextStyle(fontSize: 12))
                else
                  const Text("💬 ", style: TextStyle(fontSize: 12)),
                Expanded(
                    child: Text(
                  c['nombre_fb']?.toString().isNotEmpty == true
                      ? c['nombre_fb']
                      : c['email'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                )),
              ]),
              if ((c['email'] ?? '').toString().isNotEmpty)
                Text(c['email'],
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
              if ((c['telefono'] ?? '').toString().isNotEmpty)
                Text(c['telefono'],
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 4),
              Text(c['paquete'] ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text("\$${c['monto']}",
                  style: TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(children: [
                Text("Compra: ${DateFormat('dd/MM/yy').format(fecha)}",
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(width: 8),
                Text("Vence: ${DateFormat('dd/MM/yy').format(venc)}",
                    style: TextStyle(
                        color: vencido ? kOrange : Colors.white38,
                        fontSize: 11)),
              ]),
              if (nota.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text("📝 $nota",
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 11)),
                ),
            ]),
          ),
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            // Estado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: vencido
                    ? kOrange.withOpacity(0.2)
                    : kGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                vencido
                    ? "VENCIDO"
                    : (dias <= 7 ? "⚠️ ${dias}d" : "${c['meses']}m"),
                style: TextStyle(
                    color: vencido ? kOrange : kGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            // Botón notificación
            GestureDetector(
              onTap: () => toggleNotificacion(c),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: notifEnviada
                      ? const Color(0xFF0084FF).withOpacity(0.2)
                      : kCard2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: notifEnviada
                          ? const Color(0xFF0084FF)
                          : Colors.white24),
                ),
                child: Text(notifEnviada ? "✉️" : "📨",
                    style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 4),
            // Editar / Eliminar
            Row(children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 18, color: Colors.white54),
                onPressed: () => mostrarFormularioEditar(c),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Colors.red),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: kCard,
                      title: const Text("Eliminar"),
                      content: const Text("¿Eliminar este registro?"),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("Cancelar")),
                        TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("Eliminar",
                                style: TextStyle(color: kRed))),
                      ],
                    ),
                  );
                  if (ok == true) eliminarCliente(c['id']);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
          ]),
        ]),
      ),
    );
  }

  // ─── TAB DASHBOARD ───────────────────────────────────────
  Widget _tabDashboard() {
    final now = DateTime.now();
    final mesActual = mesesTexto[now.month - 1];
    final porcentajeMeta = ingresosMes / metaMes;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Tarjetas resumen
        Row(children: [
          _statCard("Activos", totalActivos.toString(), kGreen,
              Icons.check_circle_outline),
          const SizedBox(width: 10),
          _statCard("Vencidos", totalVencidos.toString(), kOrange,
              Icons.warning_amber_outlined),
          const SizedBox(width: 10),
          _statCard("Total", (totalActivos + totalVencidos).toString(),
              Colors.white54, Icons.people_outline),
        ]),
        const SizedBox(height: 12),

        // Meta del mes
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: kCard, borderRadius: BorderRadius.circular(12)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text("Meta del mes — ",
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text(mesActual,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              const Spacer(),
              GestureDetector(
                onTap: () => _editarMeta(),
                child: const Icon(Icons.edit, size: 16, color: Colors.white38),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Text("\$${ingresosMes.toStringAsFixed(0)}",
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              Text(" / \$${metaMes.toStringAsFixed(0)}",
                  style: const TextStyle(fontSize: 14, color: Colors.white38)),
              const Spacer(),
              Text(
                  porcentajeMeta >= 1
                      ? "✅ META SUPERADA"
                      : "${(porcentajeMeta * 100).toStringAsFixed(0)}%",
                  style: TextStyle(
                      color: porcentajeMeta >= 1 ? kGreen : kOrange,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: porcentajeMeta.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: kCard2,
                valueColor: AlwaysStoppedAnimation(
                    porcentajeMeta >= 1 ? kGreen : kOrange),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),

        // Gráfica de barras por mes
        const Text("Ingresos por mes (año actual)",
            style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          height: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: kCard, borderRadius: BorderRadius.circular(12)),
          child: _graficaBarras(),
        ),
        const SizedBox(height: 12),

        // Vencidos sin notificación
        const Text("Vencidos sin avisar",
            style: TextStyle(
                color: kOrange, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ...clientes
            .where(
                (c) => estaVencido(c) && !(c['notificacion_enviada'] ?? false))
            .take(10)
            .map(
              (c) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kOrange.withOpacity(0.4)),
                ),
                child: Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            c['nombre_fb']?.toString().isNotEmpty == true
                                ? c['nombre_fb']
                                : c['email'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(c['paquete'] ?? '',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11)),
                      ])),
                  GestureDetector(
                    onTap: () => toggleNotificacion(c),
                    child: const Text("📨", style: TextStyle(fontSize: 22)),
                  ),
                ]),
              ),
            ),
      ]),
    );
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _graficaBarras() {
    final mesesOrden = mesesTexto.take(DateTime.now().month).toList();
    final maxVal = ingresosPorMes.values.isEmpty
        ? 1.0
        : ingresosPorMes.values.reduce((a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: mesesOrden.map((mes) {
        final val = ingresosPorMes[mes] ?? 0;
        final ratio = maxVal > 0 ? val / maxVal : 0.0;
        final isCurrentMonth = mes == mesesTexto[DateTime.now().month - 1];

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (val > 0)
                Text("\$${(val / 1000).toStringAsFixed(0)}k",
                    style: TextStyle(
                        color: isCurrentMonth ? kGreen : Colors.white38,
                        fontSize: 8)),
              const SizedBox(height: 2),
              Container(
                height: (ratio * 130).clamp(4.0, 130.0),
                decoration: BoxDecoration(
                  color: isCurrentMonth ? kGreen : kRed.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Text(mes.substring(0, 3),
                  style: TextStyle(
                    color: isCurrentMonth ? kGreen : Colors.white38,
                    fontSize: 8,
                    fontWeight:
                        isCurrentMonth ? FontWeight.bold : FontWeight.normal,
                  )),
            ]),
          ),
        );
      }).toList(),
    );
  }

  void _editarMeta() {
    final ctrl = TextEditingController(text: metaMes.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        title: const Text("Meta mensual"),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: "Meta en \$",
            labelStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kRed),
            onPressed: () {
              setState(() => metaMes = double.tryParse(ctrl.text) ?? metaMes);
              Navigator.pop(context);
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  // ─── DROPDOWNS ───────────────────────────────────────────
  Widget _dropdownCompacto(String label, String value, List<String> items,
      Function(String) onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38)),
      DropdownButton<String>(
        value: items.contains(value) ? value : items.first,
        dropdownColor: kCard2,
        underline: Container(height: 1, color: Colors.white12),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        items: items
            .map((v) => DropdownMenuItem(
                value: v, child: Text(v, overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: (v) => onChanged(v!),
      ),
    ]);
  }

  Widget _dropdownMes(String label, int? value, Function(int?) onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38)),
      DropdownButton<int?>(
        value: value,
        dropdownColor: kCard2,
        underline: Container(height: 1, color: Colors.white12),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text("Todos")),
          ...List.generate(
              12,
              (i) => DropdownMenuItem<int?>(
                  value: i + 1, child: Text(mesesTexto[i]))),
        ],
        onChanged: onChanged,
      ),
    ]);
  }
}
