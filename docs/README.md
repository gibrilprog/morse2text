# Morse2Text

Morse2Text : projet en C++ pour traduire des appuis en Morse, puis du Morse vers du texte lisible.

- un clic court genere un point Morse : `.`
- un appui long d'environ 1 seconde genere un trait Morse : `-`
- une inactivite d'environ 2 secondes est interpretee comme un espace entre deux mots
- le Morse obtenu peut ensuite etre retranscrit en texte clair

## Compilation

```sh
make
```

Les executables :

```sh
./build/morse2text
./build/morse2text_gui
```

## Utilisation

Convertir du texte vers le Morse :

```sh
./build/morse2text --text "SOS TEST"
```

Convertir du Morse vers le texte :

```sh
./build/morse2text --morse "... --- ... / - . ... -"
```

Convention utilisee :

- un espace separe deux lettres Morse
- `/` separe deux mots

## Interface graphique

Compiler la fenetre macOS :

```sh
make gui
```

Lancer la fenetre :

```sh
./build/morse2text_gui
```

La fenetre est divisee en deux parties :

- a gauche, un bouton qui reste visuellement presse tant que le clic est maintenu
- le bouton joue un son type Morse continu tant que le clic est maintenu
- a droite, une zone vide reservee pour la future retranscription texte

## Unit_Tests

```sh
make test
```

Les tests couvrent le dictionnaire Morse, la traduction texte/Morse, la traduction Morse/texte et l'interpretation logique des appuis court/long.

## Architecture

```text
include/morse2text/      Headers publics du projet
src/                     Implementation C++
src/gui_main.mm          Fenetre macOS native
tests/                   Tests unitaires sans dependance externe
docs/README.md           Documentation principale
docs/changelogs/         Historique des changements
Makefile                 Compilation, tests et nettoyage
```

## Tableau Morse

```text
| Caractere |  Morse   | Caractere |  Morse   | Caractere |  Morse   | Caractere |  Morse   |
|-----------|----------|-----------|----------|-----------|----------|-----------|----------|
|     A     |   .-     |     J     |   .---   |     S     |   ...    |     1     |   .----  |
|     B     |   -...   |     K     |   -.-    |     T     |   -      |     2     |   ..---  |
|     C     |   -.-.   |     L     |   .-..   |     U     |   ..-    |     3     |   ...--  |
|     D     |   -..    |     M     |   --     |     V     |   ...-   |     4     |   ....-  |
|     E     |   .      |     N     |   -.     |     W     |   .--    |     5     |   .....  |
|     F     |   ..-.   |     O     |   ---    |     X     |   -..-   |     6     |   -....  |
|     G     |   --.    |     P     |   .--.   |     Y     |   -.--   |     7     |   --...  |
|     H     |   ....   |     Q     |   --.-   |     Z     |   --..   |     8     |   ---..  |
|     I     |   ..     |     R     |   .-.    |     0     |   -----  |     9     |   ----.  |
|     .     |   .-.-.- |     ,     |   --..-- |     ?     |   ..--.. |     !     |   -.-.-- |
|     :     |   ---... |     ;     |   -.-.-. |     /     |   -..-.  |     -     |   -....- |
|     (     |   -.--.  |     )     |   -.--.- |     @     |   .--.-. |           |          |
```
