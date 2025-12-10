import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../drift/app_database.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

class BookSpine extends StatefulWidget {
  final Book book;
  final double width;
  final double height;

  const BookSpine({
    super.key,
    required this.book,
    required this.width,
    required this.height,
  });

  @override
  State<BookSpine> createState() => _BookSpineState();
}

class _BookSpineState extends State<BookSpine> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cover = (widget.book.coverPath != null &&
            File(widget.book.coverPath!).existsSync())
        ? widget.book.coverPath!
        : '';

    return GestureDetector(
      onTap: () => context.go('/book/${widget.book.id}'),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()
            ..translateByVector3(
              Vector3(0, _hover ? -10 : 0, 0),
            ),
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: _hover ? 0.6 : 0.4,
                  ),
                  blurRadius: _hover ? 20 : 10,
                  offset: Offset(4, _hover ? 12 : 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  /// COVER
                  cover.isNotEmpty
                      ? Image.file(
                          File(cover),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),

                  /// EDGE HIGHLIGHT
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.1),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.3),
                        ],
                      ),
                    ),
                  ),

                  /// TITLE + MENU + THEME
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.9),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.book.title,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),

                          /// POPUP MENU (FIXED)
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                              size: 16,
                              color: Colors.white,
                            ),
                            onSelected: (String value) {
                              if (value == 'edit') {
                                context.go('/edit-book/${widget.book.id}');
                              }
                            },
                            itemBuilder: (BuildContext context)
                                => <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(
                                value: 'edit',
                                child: Text('Edit Buku'),
                              ),
                            ],
                          ),

                          /// THEME / SHELF
                          if (widget.book.theme != null &&
                              widget.book.theme!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                widget.book.theme!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.6),
                                  fontSize: 8,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    final idx = widget.book.title.hashCode.abs() % 6;
    final colors = [
      Colors.indigo[300]!,
      Colors.teal[400]!,
      Colors.amber[700]!,
      Colors.deepOrange[400]!,
      Colors.purple[400]!,
      Colors.green[600]!,
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors[idx],
            colors[idx].withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.book,
          size: widget.width * 0.4,
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
