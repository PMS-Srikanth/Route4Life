/**
 * Generates a preparation TODO list for the hospital based on patient condition notes.
 * Uses keyword matching — no external API needed.
 */

const CONDITIONS = [
  {
    keywords: ['chest pain', 'cardiac', 'heart attack', 'mi', 'myocardial', 'angina'],
    todos: [
      'Prepare ECG machine immediately',
      'Ready defibrillator (AED)',
      'Start IV access (18G antecubital)',
      'Prepare aspirin 300 mg + nitrates',
      'Alert cardiologist / cath lab team',
    ],
  },
  {
    keywords: ['stroke', 'paralysis', 'facial droop', 'slurred speech', 'hemiplegia', 'cerebral'],
    todos: [
      'Order urgent CT brain (non-contrast)',
      'Alert neurologist / stroke team',
      'Check NIHSS score on arrival',
      'Note exact symptom onset time',
      'Prepare thrombolytics if onset < 4.5 h',
    ],
  },
  {
    keywords: ['fracture', 'broken', 'ortho', 'bone injury', 'dislocation'],
    todos: [
      'Prepare splinting / immobilisation equipment',
      'Order X-ray of affected area',
      'Prepare analgesia (morphine / ketorolac)',
      'Alert orthopaedic surgeon on call',
    ],
  },
  {
    keywords: ['burns', 'burn', 'scald', 'thermal'],
    todos: [
      'Activate burns unit / prepare isolation room',
      'Prepare IV fluid resuscitation (Parkland formula)',
      'Tetanus prophylaxis ready',
      'Sterile non-adhesive dressings available',
      'Prepare IV morphine for pain',
    ],
  },
  {
    keywords: ['accident', 'trauma', 'rta', 'road accident', 'polytrauma', 'multiple injuries'],
    todos: [
      'Activate trauma team',
      'Prepare blood products (O-neg packed RBC)',
      'Book urgent CT scan (trauma protocol)',
      'Alert neurosurgery and general surgery',
      'Have two large-bore IV lines ready',
    ],
  },
  {
    keywords: ['bleeding', 'hemorrhage', 'haemorrhage', 'blood loss', 'haemorrhagic'],
    todos: [
      'Type & cross-match blood — 4 units',
      'Prepare FFP / platelets',
      'Alert general / vascular surgery',
      'Have large-bore IVs and pressure bags ready',
    ],
  },
  {
    keywords: ['unconscious', 'unresponsive', 'coma', 'gcs', 'altered consciousness'],
    todos: [
      'Prepare rapid-sequence intubation tray',
      'Point-of-care blood glucose check',
      'Order CT brain + consider LP',
      'Alert neurology / ICU team',
      'IV Naloxone ready (suspected overdose)',
    ],
  },
  {
    keywords: ['breathing', 'respiratory', 'asthma', 'copd', 'dyspnea', 'shortness of breath', 'wheezing'],
    todos: [
      'Prepare nebuliser (salbutamol / ipratropium)',
      'High-flow O₂ (15 L/min) mask ready',
      'Alert pulmonology / respiratory team',
      'SpO₂ and ETCO₂ monitoring ready',
    ],
  },
  {
    keywords: ['seizure', 'epilepsy', 'convulsion', 'fitting'],
    todos: [
      'Prepare IV lorazepam / diazepam',
      'Padded environment on arrival trolley',
      'Point-of-care blood glucose check',
      'Neurologist on standby',
      'IV Thiamine if alcoholism suspected',
    ],
  },
  {
    keywords: ['diabetic', 'hypoglycemia', 'glucose', 'sugar', 'dka', 'ketoacidosis'],
    todos: [
      'Dextrose 50% (25 g IV) ready',
      'Blood glucose monitor at bedside',
      'IV access and fluid resuscitation prepared',
      'Check ketones if hyperglycaemia',
    ],
  },
  {
    keywords: ['allergic', 'anaphylaxis', 'anaphylactic', 'allergic reaction', 'bee sting'],
    todos: [
      'Prepare IM Adrenaline (1:1000, 0.5 mg)',
      'IV antihistamine and hydrocortisone ready',
      'High-flow O₂ prepared',
      'Airway management team on standby',
    ],
  },
  {
    keywords: ['obstetric', 'pregnant', 'labour', 'delivery', 'contractions', 'trimester'],
    todos: [
      'Alert obstetrics team',
      'Prepare emergency delivery kit',
      'Book urgent obstetric ultrasound',
      'Neonatal team on standby',
    ],
  },
];

// Default minimal prep when no keywords match
const DEFAULT_TODOS = [
  'Prepare A&E bay and monitoring',
  'IV access and blood panel ready',
  'Alert on-call physician',
];

/**
 * @param {string} conditionNotes - free-text from paramedic
 * @returns {{ task: string, completed: boolean }[]}
 */
function generateTodos(conditionNotes) {
  if (!conditionNotes || conditionNotes.trim().length === 0) {
    return DEFAULT_TODOS.map(task => ({ task, completed: false }));
  }

  const lower = conditionNotes.toLowerCase();
  const matched = new Set();

  for (const condition of CONDITIONS) {
    if (condition.keywords.some(kw => lower.includes(kw))) {
      condition.todos.forEach(t => matched.add(t));
    }
  }

  if (matched.size === 0) {
    return DEFAULT_TODOS.map(task => ({ task, completed: false }));
  }

  return [...matched].map(task => ({ task, completed: false }));
}

module.exports = { generateTodos };
