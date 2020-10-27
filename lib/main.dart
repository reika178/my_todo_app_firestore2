import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:core';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  runApp(TodoApp());
}

class Todo {
  String id;
  String title;
  String note;

  Todo({this.id, @required this.title, @required this.note});
  Todo.newTodo() {
    title = "";
    note = "";
  }
  // @required 必須パラメターとなる

  assignUUID() {
    id = Uuid().v4();
  }
    // ランダムなIDを取得

  factory Todo.fromMap(Map<String, dynamic> json) => Todo(
    id: json["id"],
    title: json["title"],
    note: json["note"] 
  );
    // factory コンストラクターではオブジェクトの生成から制御。
    // これを使って Singleton パターンのオブジェクトを作ることができる。

    // Map:2つの情報をキー（key）と値（value）をペアとして格納する。
    // Map<キーの型, 値の型> マップ変数 = new HashMap<キーの型, 値の型>();

    // JSON:JavaScript Object Notationの略で、テキストベースのデータフォーマット。

    // fromMap関数:typeの新しいインスタンスを作成し、dataObjectのデータをそのインスタンスにマッピングする。

  Map<String, dynamic> toMap() => {
    "id": id,
    "title": title,
    "note": note
  };
}
    // toMap():このイベントを、StandardMessageCodecでエンコードできるマップに変換。

class TodoBloc {
  
  final _todoController = StreamController<List<Todo>>();
  Stream<List<Todo>> get todoStream => _todoController.stream;
  // StreamController:制御するストリームを持つコントローラー。
  // ストリームでデータ、エラー、および完了イベントを送信できる。
  // このクラスを使用して、他の人がリッスンできる単純なストリームを作成し、そのストリームにイベントをプッシュできる。

  getTodos() async {
    _todoController.sink.add(await DBProvider.db.getAllTodos());
  }
    // 同期操作：同期操作は、完了するまで他の操作の実行をブロック。
    // 同期機能：同期機能は同期操作のみを実行。
    // 非同期操作：開始されると、非同期操作により、完了する前に他の操作を実行できる。
    // 非同期関数：非同期関数は、少なくとも1つの非同期操作を実行し、同期操作も実行できる。

    // async：async関数の本体の前にキーワードを使用して、非同期としてマークすることができる。
    // sinkに流す

  TodoBloc() {
    getTodos();
  }

  dispose() {
    _todoController.close();
  }
  // dispose:Stateを永続的に削除する
  // 画面をおとすときやストリーム停止で使う

  create(Todo todo) {
    todo.assignUUID();
    DBProvider.db.createTodo(todo);
    getTodos();
  }

  update(Todo todo) {
    DBProvider.db.updateTodo(todo);
    getTodos();
  }

  delete(String id) {
    DBProvider.db.deleteTodo(id);
    getTodos();
  }
}

class TodoApp extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: ConstText.appTitle,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Provider<TodoBloc>(
        create: (context) => new TodoBloc(),
        dispose: (context, bloc) => bloc.dispose(),
        child: TodoListView()
        ),
    );
  }
}
// Provider:ツリーの下位にある Widget に情報を効率良く渡すことができる。

class TodoListView extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
  final _bloc = Provider.of<TodoBloc>(context, listen: false);
  // false: リビルドを防ぐ。

    return Scaffold(
      appBar: AppBar(title: Text(ConstText.todoListView)),
      body: StreamBuilder<List<Todo>>(
      // StreamBuilder:指定したstreamにデータが流れてくると、自動で再描画が実行される。
        stream: _bloc.todoStream,
        builder: (BuildContext context, AsyncSnapshot<List<Todo>> snapshot) {
          // snapshot:アプリの 初回の起動の高速化 のために使っている。
          if (snapshot.hasData) {
            return ListView.builder(
              itemCount: snapshot.data.length,
              itemBuilder: (BuildContext context, int index) {

                Todo todo = snapshot.data[index];

                // スワイプして消すDismissible
                return Dismissible(
                  key: Key(todo.id),
                  background: _backgroundOfDismissible(),
                  secondaryBackground: _secondaryBackgroundOfDismissble(),
                  onDismissed: (direction) {
                      _bloc.delete(todo.id);
                  },
                  child: Card(
                    child: ListTile(
                      onTap: () {
                        _moveToEditView(context, _bloc, todo);
                      },
                      title: Text("${todo.title}"),
                      subtitle: Text("${todo.note}"),
                      isThreeLine: true,
                    )
                  ),
                );
              },
            );
          } 
        },
      ),
      floatingActionButton: FloatingActionButton(
          child: Icon(Icons.add),
          onPressed: () { _moveToCreateView(context, _bloc);},
      ),
    );
  }

_moveToEditView(BuildContext context, TodoBloc bloc, Todo todo) => Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => AddTodo(todoBloc: bloc, todo: todo))
);

_moveToCreateView(BuildContext context, TodoBloc bloc) => Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => AddTodo(todoBloc: bloc, todo: Todo.newTodo()))
);

_backgroundOfDismissible() => Container(
  alignment: Alignment.centerLeft,
  color: Colors.green,
  child: Padding(
    padding: EdgeInsets.fromLTRB(20,0,0,0),
    child: Icon(Icons.done, color: Colors.white),
  )
);

_secondaryBackgroundOfDismissble() => Container(
  alignment: Alignment.centerRight,
  color: Colors.green,
  child: Padding(
    padding: EdgeInsets.fromLTRB(0,0,20,0),
    child: Icon(Icons.done, color: Colors.white),
  )
);
}


class AddTodo extends StatelessWidget {

  final TodoBloc todoBloc;
  final Todo todo;
  final Todo _newTodo = Todo.newTodo();

  AddTodo({Key key, @required this.todoBloc, @required this.todo}) {
    _newTodo.id = todo.id;
    _newTodo.title = todo.title;
    _newTodo.note = todo.note;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:AppBar(title: Text(ConstText.todoEditView),),
        body: Container(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            children: <Widget>[
              _titleTextFormField(),
              _noteTextFormField(),
              _confirmButton(context)
            ],
          ),
        ),
     );
   }

  Widget _titleTextFormField() => TextFormField(
    decoration: InputDecoration(labelText: "タイトル"),
    initialValue: _newTodo.title,
    onChanged: _setTitle,
  );

  void _setTitle(String title) {
    _newTodo.title = title;
  }

  Widget _noteTextFormField() => TextFormField(
    decoration: InputDecoration(labelText: "メモ"),
    initialValue: _newTodo.note,
    maxLines: 3,
    onChanged: _setNote,
  );

  void _setNote(String note) {
    _newTodo.note = note;
  }

  Widget _confirmButton(BuildContext context) => RaisedButton(
    child: Text("Add"),
    onPressed: () {
      if (_newTodo.id == null) {
        todoBloc.create(_newTodo);
      } else {
        todoBloc.update(_newTodo);
      }
    Navigator.of(context).pop();
    },
  );
}

class ConstText {
  static final appTitle = "Todo App";
  static final todoListView = "Todo List";
  static final todoEditView = "Todo Edit";
  static final todoCreateView = "New Todo";
}

// データベースを取得する関数を追加
class DBProvider {
  DBProvider._();
  static final DBProvider db = DBProvider._();

  static Database _database;
  static final _tableName = "Todo";

  Future<Database> get database async {
    if (_database != null)
      return _database;

    // DBがなかったら作る
    _database = await initDB();
    return _database;
  }

  Future<Database> initDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    // getApplicationDocumentsDirectory():アプリケーション専用のファイルを配置するディレクトリへのパスを返す。

    String path = join(documentsDirectory.path, "TodoDB.db");

    return await openDatabase(path, version: 1, onCreate: _createTable);
    // openDatabaseメソッドを使用することでDBインスタンスを取得することができる。
  }

  Future<void> _createTable(Database db, int version) async {
    return await db.execute(
      "CREATE TABLE $_tableName ("
      "id TEXT PRIMARY KEY,"
      "title TEXT,"
      "note TEXT"
      ")"
    );
  }

  createTodo(Todo todo) async {
    final db = await database;
    var res = await db.insert(_tableName, todo.toMap());
    return res;
  }

  getAllTodos() async {
    final db = await database;
    var res = await db.query(_tableName);
    List<Todo> list =
        res.isNotEmpty ? res.map((c) => Todo.fromMap(c)).toList() : [];
    return list;
  }

  updateTodo(Todo todo) async {
    final db = await database;
    var res = await db.update(
      _tableName,
      todo.toMap(),
      where: "id = ?",
      whereArgs: [todo.id]
    );
    return res;
  }

  deleteTodo(String id) async {
    final db = await database;
    var res = db.delete(
      _tableName,
      where: "id = ?",
      whereArgs: [id]
    );
    return res;
  }

}