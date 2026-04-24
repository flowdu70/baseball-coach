# ⚾ Baseball Coach — Application Flutter

Application mobile de coaching baseball (iOS & Android) permettant d'analyser les lancers selon leurs paramètres physiques.

## Fonctionnalités MVP

### 🎯 Calculateur de lancer
- Contrôle de 3 paramètres via sliders :
  - **Vitesse de la balle** (60–165 km/h)
  - **Vitesse de rotation** (500–3500 tr/min)
  - **Angle de rotation** (0–90°)
- Calcul de l'effet Magnus (déviation latérale + chute verticale)
- Classification automatique du type de lancer (Fastball, Slider, Curveball, Changeup, Sinker, Cutter…)
- Visualisation 2D de la trajectoire

### 👥 Gestion des joueurs
- Création de profils joueurs (nom + position)
- Sélection du joueur actif pour lier les lancers
- Suppression avec cascade sur les lancers

### 📊 Stats par joueur
- Historique complet des lancers
- Graphiques d'évolution vitesse + rotation (20 derniers)
- Répartition des types de lancers

### 💡 Conseils d'amélioration
- Moteur de règles analysant les 10 derniers lancers
- Conseils sur la vitesse, la rotation, l'angle et la consistance

## Installation

### Prérequis
- Flutter ≥ 3.0 ([installer Flutter](https://docs.flutter.dev/get-started/install))
- Android Studio ou Xcode selon la plateforme cible

### Lancer l'app
```bash
cd baseball_coach
flutter pub get
flutter run
```

### Build production
```bash
# Android APK
flutter build apk --release

# iOS
flutter build ios --release
```

## Architecture

```
lib/
├── main.dart                    # Point d'entrée
├── models/
│   ├── player.dart              # Modèle joueur
│   └── throw_record.dart        # Modèle lancer
├── services/
│   ├── database_service.dart    # SQLite via sqflite
│   ├── physics_service.dart     # Calcul effet Magnus
│   └── advice_service.dart      # Moteur de conseils
├── providers/
│   ├── player_provider.dart     # State joueurs
│   └── throw_provider.dart      # State lancers
├── screens/
│   ├── home_screen.dart         # Navigation principale
│   ├── calculator_screen.dart   # Calculateur
│   ├── players_screen.dart      # Liste joueurs
│   └── player_detail_screen.dart # Stats + conseils
└── widgets/
    └── trajectory_painter.dart  # Visualisation trajectoire
```

## Physique — Effet Magnus

Le calcul utilise la formule de Magnus simplifiée :

- **Cl** (coefficient de portance) = `(ω × r) / v`
- **Force Magnus** = `½ × ρ × A × Cl × v²`
- **Déviation** = `½ × (F/m) × t²`

Avec :
- ω = vitesse angulaire (rad/s)
- r = rayon de la balle (0.037 m)
- v = vitesse linéaire (m/s)
- ρ = densité de l'air (1.225 kg/m³)
- A = section transversale de la balle
- t = temps de vol (distance monticule-marbre / vitesse)
