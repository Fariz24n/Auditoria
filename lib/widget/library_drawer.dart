// lib/widget/library_drawer.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../drift/app_database.dart';

class LibraryDrawer extends StatelessWidget {
  final AppDatabase db;
  
  const LibraryDrawer({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // 1. Header (Gambar Bulan/Malam seperti referensi)
          const UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: Color(0xFF1E1E2C), // Dark blue/grey
              image: DecorationImage(
                image: AssetImage('assets/moon_bg.png'), // Ganti dengan aset Anda jika ada
                fit: BoxFit.cover,
                opacity: 0.4,
              ),
            ),
            accountName: Text("Auditoria Reader", style: TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text("Selamat membaca malam ini."),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.amber,
              child: Icon(Icons.nightlight_round, color: Colors.black87),
            ),
          ),

          // 2. Menu Utama
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildMenuItem(context, icon: Icons.history, title: 'Recent List', shelfFilter: 'recent'),
                
                const Divider(),

                // 3. "My Shelf" - Expandable Menu
                StreamBuilder<List<String>>(
                  stream: db.watchUniqueThemes(),
                  builder: (context, snapshot) {
                    final shelves = snapshot.data ?? [];
                    
                    return ExpansionTile(
                      leading: const Icon(Icons.shelves),
                      title: const Text("Rak Buku Saya"),
                      initiallyExpanded: true,
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.only(left: 72),
                          title: const Text("(Semua Buku)"),
                          onTap: () {
                            context.pop();
                            context.go('/');
                          },
                        ),
                        ListTile(
                          contentPadding: const EdgeInsets.only(left: 72),
                          title: const Text("Favorit"),
                          leading: const Icon(Icons.star, size: 16, color: Colors.amber),
                          onTap: () {
                            context.pop();
                            context.go('/?filter=favorites');
                          },
                        ),
                        ...shelves.map((shelfName) => ListTile(
                          contentPadding: const EdgeInsets.only(left: 72),
                          title: Text(shelfName),
                          onTap: () {
                            context.pop();
                            context.go('/?shelf=$shelfName');
                          },
                        )),
                      ],
                    );
                  },
                ),

                const Divider(),
                _buildMenuItem(context, icon: Icons.settings, title: 'Pengaturan', shelfFilter: null),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, {required IconData icon, required String title,String? shelfFilter}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        // Logika menu lain bisa ditaruh sini
        Navigator.pop(context); 
      },
    );
  }
}