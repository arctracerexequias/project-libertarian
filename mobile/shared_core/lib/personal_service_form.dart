import 'package:flutter/material.dart';

// Stable IDs keep answers independent of display copy and make conditional
// answers safe to omit when their parent selection changes.
enum ServiceFieldKind { choice, multiple, number, text }

class ServiceField {
  final String id;
  final String label;
  final ServiceFieldKind kind;
  final List<String> options;
  final bool optional;
  final bool private;
  final int maxLength;
  final String? dependsOn;
  final List<String> visibleFor;

  const ServiceField(this.id, this.label, this.kind,
      {this.options = const [],
      this.optional = false,
      this.private = false,
      this.maxLength = 500,
      this.dependsOn,
      this.visibleFor = const ['Yes']});

  bool visible(Map<String, dynamic> answers) {
    if (dependsOn == null) return true;
    final value = answers[dependsOn];
    return value is List
        ? value.any(visibleFor.contains)
        : visibleFor.contains(value);
  }
}

const _yesNo = ['Yes', 'No'];
const _gender = ServiceField(
    'gender', 'Preferred provider gender', ServiceFieldKind.choice,
    options: ['Female', 'Male', 'Either']);
const _home = ServiceField(
    'home_service', 'Do you require home service?', ServiceFieldKind.choice,
    options: _yesNo);
const _illness = ServiceField(
    'illness', 'Any pre-existing illness or diseases?', ServiceFieldKind.choice,
    options: _yesNo, private: true);
const _illnessDetails = ServiceField('illness_details',
    'Illness details and medication schedule, if any', ServiceFieldKind.text,
    dependsOn: 'illness', private: true);
const _recent = ServiceField('recent',
    'Any recent surgery, injury or pregnancy?', ServiceFieldKind.choice,
    options: _yesNo, private: true);
const _recentDetails = ServiceField(
    'recent_details', 'Details of the recent condition', ServiceFieldKind.text,
    dependsOn: 'recent', private: true);
const _otherTasks = ServiceField(
    'other_tasks', 'Other tasks', ServiceFieldKind.text,
    dependsOn: 'tasks', visibleFor: ['Others'], maxLength: 80);

const personalServices = <String, List<ServiceField>>{
  'Massage': [
    _gender,
    ServiceField('home_service', 'Do you require home / hotel service?',
        ServiceFieldKind.choice,
        options: _yesNo),
    ServiceField('clients', 'Number of clients', ServiceFieldKind.number),
    _illness,
    _illnessDetails,
    ServiceField('recent', 'Any recent surgery, tooth extraction or pregnancy?',
        ServiceFieldKind.choice,
        options: _yesNo, private: true),
    _recentDetails,
  ],
  'Nail Care': [
    _home,
    ServiceField('clients', 'Number of clients', ServiceFieldKind.number),
    _illness,
    _illnessDetails,
    ServiceField('treatment', 'Nail service', ServiceFieldKind.choice,
        options: ['Manicure', 'Pedicure', 'Both']),
    ServiceField('extras', 'Additional services', ServiceFieldKind.multiple,
        optional: true,
        options: [
          'Foot Spa',
          'Hand / Foot Massage',
          'Nail Art',
          'Nail Polish',
          'Gel Polish'
        ]),
  ],
  'Tailoring': [
    ServiceField('items', 'Number of items', ServiceFieldKind.number),
    ServiceField('materials', 'Do you have materials for your project?',
        ServiceFieldKind.choice,
        options: _yesNo),
    ServiceField(
        'project_gender', 'Gender-specific project?', ServiceFieldKind.choice,
        options: ['Male', 'Female', 'Unisex', 'No']),
    ServiceField('custom_measurements', 'Do you need custom measurements?',
        ServiceFieldKind.choice,
        options: _yesNo),
    ServiceField(
        'measurements', 'Measurements (include units)', ServiceFieldKind.text,
        dependsOn: 'custom_measurements', visibleFor: ['No'], private: true),
  ],
  'Housekeeping': [
    _gender,
    ServiceField('tasks', 'Select all tasks the provider will do',
        ServiceFieldKind.multiple,
        options: [
          'General Cleaning',
          'Basic Cleaning',
          'Cooking',
          'Ironing',
          'Laundry',
          'Yard Cleaning',
          'Others'
        ]),
    _otherTasks,
  ],
  'Landscaping': [
    ServiceField('providers', 'Number of landscapers', ServiceFieldKind.number),
    ServiceField('tasks', 'Select all tasks the provider will do',
        ServiceFieldKind.multiple,
        options: [
          'Pruning / Trimming',
          'Pest Control',
          'Mowing',
          'Fertilizing',
          'Planting',
          'Hardscaping',
          'Irrigation Support',
          'Weeding / Mulching',
          'Others'
        ]),
    _otherTasks,
  ],
  'Babysitting': [
    ServiceField('children', 'Number of children', ServiceFieldKind.number),
    ServiceField('ages', 'Children’s ages (separate with commas; use years)',
        ServiceFieldKind.text,
        maxLength: 100, private: true),
    ServiceField('illness', 'Any injuries, diseases or special needs?',
        ServiceFieldKind.choice,
        options: _yesNo, private: true),
    _illnessDetails,
  ],
  'Caregiving / Nursing': [
    _gender,
    ServiceField('role', 'Nurse or caregiver?', ServiceFieldKind.choice,
        options: ['Nurse', 'Caregiver']),
    ServiceField(
        'age', 'Age of person receiving care (years)', ServiceFieldKind.number,
        private: true),
    _illness,
    _illnessDetails,
    _recent,
    _recentDetails,
  ],
  'Pet Care': [
    _home,
    ServiceField('pets', 'Number of pets', ServiceFieldKind.number),
    ServiceField('pet_types', 'Pet types', ServiceFieldKind.multiple,
        options: ['Dog', 'Cat', 'Others']),
    ServiceField('other_pets', 'Other pet types', ServiceFieldKind.text,
        dependsOn: 'pet_types', visibleFor: ['Others']),
    _illness,
    _illnessDetails,
    ServiceField('tasks', 'Pet care services', ServiceFieldKind.multiple,
        options: ['Grooming', 'Lodging', 'Nanny']),
  ],
  'Tutorial': [
    _gender,
    ServiceField('grade', 'Grade / year level', ServiceFieldKind.text,
        maxLength: 80),
    ServiceField('age', 'Student age (years)', ServiceFieldKind.number,
        private: true),
    ServiceField('special_needs', 'Does the student have special needs?',
        ServiceFieldKind.choice,
        options: _yesNo, private: true),
    ServiceField(
        'special_details', 'Special needs details', ServiceFieldKind.text,
        dependsOn: 'special_needs', private: true),
    ServiceField('subjects', 'Subjects', ServiceFieldKind.multiple, options: [
      'Math',
      'Science',
      'English',
      'Filipino',
      'Araling Panlipunan'
    ]),
    ServiceField('hours', 'Number of tutorial hours', ServiceFieldKind.number),
    ServiceField('topics', 'Topics to cover', ServiceFieldKind.text),
  ],
};

String canonicalPersonalService(String name) =>
    const {
      'Manicure & Pedicure': 'Nail Care',
      'Elderly Care': 'Caregiving / Nursing',
      'Child Care': 'Babysitting',
      'Tutorial Services': 'Tutorial',
      'House Keeping': 'Housekeeping',
      'Pet Grooming': 'Pet Care',
    }[name] ??
    name;

String? validatePersonalAnswers(String service, Map<String, dynamic> answers) {
  for (final field in personalServices[service] ?? <ServiceField>[]) {
    if (!field.visible(answers)) continue;
    final value = answers[field.id];
    final empty = value == null ||
        value.toString().trim().isEmpty ||
        (value is List && value.isEmpty);
    if (empty && field.optional) continue;
    if (empty) return 'Complete: ${field.label}.';
    if (field.kind == ServiceFieldKind.number) {
      final count = int.tryParse(value.toString());
      final min = field.id == 'age' ? 0 : 1;
      if (count == null || count < min || count > 120)
        return 'Enter a valid number for ${field.label.toLowerCase()} (up to 120).';
    }
    if (field.kind == ServiceFieldKind.choice && !field.options.contains(value))
      return 'Select: ${field.label}.';
    if (field.kind == ServiceFieldKind.multiple &&
        (value is! List || value.any((v) => !field.options.contains(v))))
      return 'Select: ${field.label}.';
    if (field.kind == ServiceFieldKind.text &&
        value.toString().length > field.maxLength)
      return '${field.label} is too long.';
  }
  if (service == 'Babysitting') {
    final ages = (answers['ages'] ?? '')
        .toString()
        .split(',')
        .map((v) => double.tryParse(v.trim()))
        .toList();
    if (ages.length != int.tryParse('${answers['children']}') ||
        ages.any(
            (age) => age == null || !age.isFinite || age < 0 || age >= 18)) {
      return 'Enter one age per child, from 0 to under 18 years (for example 0.5, 5).';
    }
  }
  return null;
}

Map<String, String> personalAnswerSummary(
    String service, Map<String, dynamic> answers,
    {bool? private}) {
  return {
    for (final field in personalServices[service] ?? <ServiceField>[])
      if (field.visible(answers) &&
          answers[field.id] != null &&
          (private == null || field.private == private) &&
          answers[field.id].toString().isNotEmpty &&
          !(answers[field.id] is List && (answers[field.id] as List).isEmpty))
        field.label: answers[field.id] is List
            ? (answers[field.id] as List).join(', ')
            : answers[field.id].toString().trim(),
  };
}

class PersonalServiceForm extends StatelessWidget {
  final String service;
  final Map<String, dynamic> answers;
  final void Function(String, dynamic) onChanged;
  const PersonalServiceForm(
      {super.key,
      required this.service,
      required this.answers,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final field in personalServices[service] ?? <ServiceField>[])
            if (field.visible(answers))
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(field.label,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF006D99))),
                      const SizedBox(height: 8),
                      if (field.kind == ServiceFieldKind.choice ||
                          field.kind == ServiceFieldKind.multiple)
                        Wrap(spacing: 8, runSpacing: 4, children: [
                          for (final option in field.options)
                            FilterChip(
                              label: Text(option),
                              selected: field.kind == ServiceFieldKind.multiple
                                  ? (answers[field.id] as List? ?? [])
                                      .contains(option)
                                  : answers[field.id] == option,
                              onSelected: (selected) {
                                if (field.kind == ServiceFieldKind.choice) {
                                  onChanged(field.id, option);
                                } else {
                                  final values = List<String>.from(
                                      answers[field.id] ?? []);
                                  selected
                                      ? values.add(option)
                                      : values.remove(option);
                                  onChanged(field.id, values);
                                }
                              },
                            ),
                        ])
                      else
                        TextFormField(
                          key: ValueKey('$service-${field.id}'),
                          initialValue: answers[field.id]?.toString() ?? '',
                          keyboardType: field.kind == ServiceFieldKind.number
                              ? TextInputType.number
                              : TextInputType.text,
                          maxLength: field.kind == ServiceFieldKind.text
                              ? field.maxLength
                              : 3,
                          maxLines: field.kind == ServiceFieldKind.text &&
                                  field.maxLength > 100
                              ? 3
                              : 1,
                          decoration: InputDecoration(
                              labelText: field.label,
                              counterText: field.kind == ServiceFieldKind.number
                                  ? ''
                                  : null),
                          onChanged: (value) => onChanged(field.id, value),
                        ),
                    ]),
              ),
          if (service == 'Babysitting' || service == 'Caregiving / Nursing')
            const Text(
                'This service is for private residences. Discuss any travel beyond the booked address and additional costs with your provider.'),
          const SizedBox(height: 12),
          const Text(
              'Health details and personal information are shared only with your accepted provider. Keep them out of the public job title and notes.'),
        ],
      );
}
