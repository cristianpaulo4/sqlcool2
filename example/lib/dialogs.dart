import 'package:flutter/material.dart';
import 'database.dart';

void insertItemDialog(BuildContext context) {
  final nameController = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Add an item"),
        actions: <Widget>[
          ElevatedButton(
            child: const Text("Cancel"),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
          ElevatedButton(
            child: const Text("Save"),
            onPressed: () {
              final txt = nameController.text;
              saveItem(txt).catchError((dynamic e) {
                throw ("Can not save item ${e.message}");
              });
              Navigator.of(context).pop(true);
            },
          ),
        ],
        content: TextField(
          controller: nameController,
          autofocus: true,
        ),
      );
    },
  );
}

void deleteItemDialog(BuildContext context, String itemName, int itemId) {
  showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("Delete $itemName?"),
        actions: <Widget>[
          ElevatedButton(
            child: const Text("Cancel"),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            child: const Text("Delete"),
            onPressed: () {
              deleteItem(itemId).catchError((dynamic e) {
                throw (e);
              });
              Navigator.of(context).pop(true);
            },
          ),
        ],
      );
    },
  );
}

void updateItemDialog(BuildContext context, String itemName) {
  final nameController = TextEditingController(text: itemName);

  showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Update item"),
        content: TextField(
          controller: nameController,
          autofocus: true,
        ),
        actions: <Widget>[
          ElevatedButton(
            child: const Text("Cancel"),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
          ElevatedButton(
            child: const Text("Save"),
            onPressed: () {
              final txt = nameController.text;
              updateItem(itemName, txt).catchError((dynamic e) {
                throw ("Can not update category $e");
              });
              Navigator.of(context).pop(true);
            },
          ),
        ],
      );
    },
  );
}
