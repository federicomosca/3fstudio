import 'package:flutter/material.dart';

String courseTypeLabel(String? type) => switch (type) {
  'group'    => 'Gruppo',
  'shared'   => 'Condiviso',
  _          => 'Personal',
};

IconData courseTypeIcon(String? type) => switch (type) {
  'group'  => Icons.group_outlined,
  'shared' => Icons.people_outline,
  _        => Icons.person_outline,
};
