import 'package:flutter/material.dart';
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
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final supabase = Supabase.instance.client;

  List clientes = [];
  List clientesFiltrados = [];

  String filtroEstado = "Todos";
  String filtroPaquete = "Todos";

  int? filtroAnio;
  int? filtroMes; // null = sin filtro de mes al iniciar

  List<String> paquetes = ["Todos"];
  List<int> listaAnios = [];

  final buscador = TextEditingController();

  Timer? autoRefresh;

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
    final now = DateTime.now();
    filtroAnio = now.year;
    filtroMes =
        null; // ✅ sin filtro de mes, muestra todos los registros del año
    cargarClientes();

    autoRefresh = Timer.periodic(const Duration(seconds: 10), (timer) {
      cargarClientes();
    });
  }

  @override
  void dispose() {
    autoRefresh?.cancel();
    super.dispose();
  }

  Future<void> cargarClientes() async {
    final data =
        await supabase.from('ventas').select().order('id', ascending: false);

    Set<String> listaPaquetes = {"Todos"};
    Set<int> anios = {};

    for (var c in data) {
      final fecha =
          DateTime.tryParse(c['fecha_compra'] ?? '') ?? DateTime.now();
      anios.add(fecha.year);

      if (c['paquete'] != null && c['paquete'] != "") {
        listaPaquetes.add(c['paquete']);
      }
    }

    clientes = data;
    paquetes = listaPaquetes.toList();
    listaAnios = anios.toList()..sort((b, a) => a.compareTo(b));

    aplicarFiltros();
  }

  bool estaVencido(Map c) {
    final fecha = DateTime.tryParse(c['fecha_compra'] ?? '') ?? DateTime.now();
    final meses = (c['meses'] ?? 1) as num;
    final venc = DateTime(fecha.year, fecha.month + meses.toInt(), fecha.day);
    return DateTime.now().isAfter(venc);
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

      final coincide = nombre.contains(texto) ||
          email.contains(texto) ||
          tel.contains(texto);

      if (filtroEstado == "Vencidos" && !vencido) return false;
      if (filtroEstado == "Activos" && vencido) return false;
      if (filtroPaquete != "Todos" && paquete != filtroPaquete) return false;
      if (filtroAnio != null && fecha.year != filtroAnio) return false;
      if (filtroMes != null && fecha.month != filtroMes) return false;

      return coincide;
    }).toList();

    setState(() {
      clientesFiltrados = res;
    });
  }

  void eliminarCliente(int id) async {
    await supabase.from('ventas').delete().eq('id', id);
    cargarClientes();
  }

  void mostrarFormularioAgregar() {
    final nombre = TextEditingController();
    final email = TextEditingController();
    final telefono = TextEditingController();
    final paquete = TextEditingController();
    final meses = TextEditingController();
    final monto = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text("Nueva venta"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                  controller: nombre,
                  decoration: const InputDecoration(hintText: "Nombre")),
              TextField(
                  controller: email,
                  decoration: const InputDecoration(hintText: "Email")),
              TextField(
                  controller: telefono,
                  decoration: const InputDecoration(hintText: "Teléfono")),
              TextField(
                  controller: paquete,
                  decoration: const InputDecoration(hintText: "Paquete")),
              TextField(
                  controller: meses,
                  decoration: const InputDecoration(hintText: "Meses")),
              TextField(
                  controller: monto,
                  decoration: const InputDecoration(hintText: "Monto")),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await supabase.from('ventas').insert({
                "nombre_fb": nombre.text,
                "email": email.text,
                "telefono": telefono.text,
                "paquete": paquete.text,
                "meses": int.tryParse(meses.text) ?? 1,
                "monto": double.tryParse(monto.text) ?? 0,
                "fecha_compra": DateTime.now().toIso8601String(),
              });

              Navigator.pop(context);
              cargarClientes();
            },
            child: const Text("Guardar"),
          )
        ],
      ),
    );
  }

  void mostrarFormularioEditar(Map c) {
    final nombre = TextEditingController(text: c['nombre_fb']);
    final email = TextEditingController(text: c['email']);
    final telefono = TextEditingController(text: c['telefono']);
    final paquete = TextEditingController(text: c['paquete']);
    final meses = TextEditingController(text: c['meses'].toString());
    final monto = TextEditingController(text: c['monto'].toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text("Editar venta"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: nombre),
              TextField(controller: email),
              TextField(controller: telefono),
              TextField(controller: paquete),
              TextField(controller: meses),
              TextField(controller: monto),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await supabase.from('ventas').update({
                "nombre_fb": nombre.text,
                "email": email.text,
                "telefono": telefono.text,
                "paquete": paquete.text,
                "meses": int.tryParse(meses.text) ?? 1,
                "monto": double.tryParse(monto.text) ?? 0,
              }).eq('id', c['id']);

              Navigator.pop(context);
              cargarClientes();
            },
            child: const Text("Guardar"),
          )
        ],
      ),
    );
  }

  void exportarCSV() {
    print("Export CSV desactivado temporalmente");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', height: 30),
            const SizedBox(width: 10),
            const Text("Remix Pro DJ POS"),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.download), onPressed: exportarCSV),
        ],
      ),
      floatingActionButton: SizedBox(
        width: 48,
        height: 48,
        child: FloatingActionButton(
          backgroundColor: const Color(0xFFFF2D55),
          onPressed: mostrarFormularioAgregar,
          child: const Icon(Icons.add, size: 24),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: buscador,
              onChanged: (_) => aplicarFiltros(),
              decoration: const InputDecoration(
                hintText: "Buscar cliente...",
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _dropdown(
                    "Estado", filtroEstado, ["Todos", "Activos", "Vencidos"],
                    (v) {
                  filtroEstado = v;
                  aplicarFiltros();
                }),
                _dropdown("Pack DJ", filtroPaquete, paquetes, (v) {
                  filtroPaquete = v;
                  aplicarFiltros();
                }),
                _dropdownMes("Mes", filtroMes, (v) {
                  filtroMes = v;
                  aplicarFiltros();
                }),
              ],
            ),
          ),
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: listaAnios.map((anio) {
                return GestureDetector(
                  onTap: () {
                    filtroAnio = anio;
                    aplicarFiltros();
                  },
                  child: Container(
                    margin: const EdgeInsets.all(5),
                    padding: const EdgeInsets.all(10),
                    color: filtroAnio == anio
                        ? Colors.greenAccent
                        : Colors.grey[800],
                    child: Text(
                      anio.toString(),
                      style: TextStyle(
                        color: filtroAnio == anio ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: clientesFiltrados.length,
              itemBuilder: (_, i) {
                final c = clientesFiltrados[i];

                final fecha = DateTime.tryParse(c['fecha_compra'] ?? '') ??
                    DateTime.now();
                final meses = (c['meses'] ?? 1) as num;
                final venc = DateTime(
                    fecha.year, fecha.month + meses.toInt(), fecha.day);
                final vencido = estaVencido(c);

                return Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: i % 2 == 0 ? Colors.black : Colors.grey[900],
                    border: Border.all(
                      color: vencido ? Colors.red : Colors.greenAccent,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c['nombre_fb'] ?? ''),
                                  Text(c['email'] ?? ''),
                                  Text(c['telefono'] ?? ''),
                                  Text("${c['paquete']} | \$${c['monto']}"),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      "Compra: ${DateFormat('dd/MM/yyyy').format(fecha)}"),
                                  Text(
                                      "Vence: ${DateFormat('dd/MM/yyyy').format(venc)}"),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            vencido ? "VENCIDO" : "${c['meses']} meses",
                            style: TextStyle(
                              color: vencido ? Colors.red : Colors.greenAccent,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () {
                                  mostrarFormularioEditar(c);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () async {
                                  final confirmar = await showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      backgroundColor: Colors.black,
                                      title: const Text("Eliminar"),
                                      content: const Text(
                                          "¿Deseas eliminar este registro?"),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text("Cancelar"),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text("Eliminar"),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmar == true && c['id'] != null) {
                                    eliminarCliente(c['id']);
                                  }
                                },
                              ),
                            ],
                          )
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Dropdown especial para Mes que soporta valor null ("Todos los meses")
  Widget _dropdownMes(String label, int? value, Function onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.white70)),
        DropdownButton<int?>(
          value: value,
          dropdownColor: Colors.black,
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text("Todos"),
            ),
            ...List.generate(12, (i) {
              return DropdownMenuItem<int?>(
                value: i + 1,
                child: Text(mesesTexto[i]),
              );
            }),
          ],
          onChanged: (v) => onChanged(v),
        ),
      ],
    );
  }

  Widget _dropdown(String label, dynamic value, List items, Function onChanged,
      [List<String>? labels]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.white70)),
        DropdownButton(
          value: value,
          dropdownColor: Colors.black,
          items: List.generate(items.length, (i) {
            final val = items[i];
            final text = labels != null ? labels[i] : val.toString();
            return DropdownMenuItem(value: val, child: Text(text));
          }),
          onChanged: (v) => onChanged(v),
        ),
      ],
    );
  }
}
