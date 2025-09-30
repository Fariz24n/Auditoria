import '../model/book.dart';

class BookService {
  static List<Book> getBooks() {
    return [
      Book(
        title: "Konrad Curze", 
        filePath: "asset/books/KONRAD CURZE THE NIGHT HAUNTER (Guy Haley).pdf", 
        coverPath: "asset/images/Curze.jpg",),
      Book(
        title: "The Devastation of Baal",
        filePath: "asset/books/The Devastation of Baal (Guy Haley).pdf",
        coverPath: "asset/images/DOB.jpg",),
      Book(
        title: "Helsreach",
        filePath: "asset/books/Hellsreach (Aaron Dembski-Bowden).pdf",
        coverPath: "asset/images/Helsreach.jpg",),
      Book(
        title: "A More Perfect Union",
        filePath: "asset/books/A More Perfect Union (Rich McCormick).pdf",
        coverPath: "asset/images/AMPU.jpg",),
    ];
  }
}
