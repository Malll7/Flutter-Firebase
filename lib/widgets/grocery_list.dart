import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:shoppinglist_app/data/categories.dart';
import 'package:shoppinglist_app/models/grocery_item.dart';
import 'package:shoppinglist_app/widgets/new_item.dart';

class GroceryList extends StatefulWidget {
  const GroceryList({super.key});

  @override
  State<GroceryList> createState() => _GroceryListState();
}

class _GroceryListState extends State<GroceryList> {
  Future<List<GroceryItem>>? _groceryFuture;

  @override
  void initState() {
    super.initState();
    _groceryFuture = _loadItems();
  }

  Future<List<GroceryItem>> _loadItems() async {
    final url = Uri.https(
      'shoppingapp-273-default-rtdb.asia-southeast1.firebasedatabase.app',
      'shopping-list.json',
    );

    final response = await http.get(url);

    if (response.statusCode >= 400) {
      throw Exception('Failed to fetch items (code ${response.statusCode})');
    }

    if (response.body == 'null') {
      return [];
    }

    final Map<String, dynamic> data = json.decode(response.body);
    final List<GroceryItem> loadedItems = [];

    data.forEach((key, value) {
      final category = categories.entries
          .firstWhere(
            (cat) => cat.value.title == value['category'],
            orElse: () => categories.entries.first,
          )
          .value;

      loadedItems.add(
        GroceryItem(
          id: key,
          name: value['name'],
          quantity: value['quantity'],
          category: category,
        ),
      );
    });

    return loadedItems;
  }

  Future<void> _addItem() async {
    await Navigator.of(context)
        .push<GroceryItem>(MaterialPageRoute(builder: (ctx) => const NewItem()));
    setState(() {
      _groceryFuture = _loadItems(); // reload items after adding
    });
  }

  void _removeItem(GroceryItem item) async {
    final url = Uri.https(
      'shoppingapp-273-default-rtdb.asia-southeast1.firebasedatabase.app',
      'shopping-list/${item.id}.json',
    );
    await http.delete(url);
    setState(() {
      _groceryFuture = _loadItems(); // reload items after removing
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Groceries'),
        actions: [IconButton(onPressed: _addItem, icon: const Icon(Icons.add))],
      ),
      body: FutureBuilder<List<GroceryItem>>(
        future: _groceryFuture,
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return const Center(child: Text('No items added yet.'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _groceryFuture = _loadItems();
              });
            },
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (ctx, index) => Dismissible(
                key: ValueKey(items[index].id),
                background: Container(color: Colors.red),
                onDismissed: (_) => _removeItem(items[index]),
                child: ListTile(
                  title: Text(items[index].name),
                  leading: Container(
                    width: 24,
                    height: 24,
                    color: items[index].category.color,
                  ),
                  trailing: Text(items[index].quantity.toString()),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
