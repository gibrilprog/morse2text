# Morse2Text

Morse2Text : projet en C++ pour traduire des appuis en Morse, puis du Morse vers du texte lisible.

- un appui d'environ 0,2 seconde genere un point Morse : `.`
- un appui d'environ 0,5 seconde genere un trait Morse : `-`
- une inactivite de 1 seconde apres un relachement valide la lettre en cours
- une inactivite de 2 secondes apres un relachement est interpretee comme un espace entre deux mots
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
- au-dessus du bouton, une jauge d'appui va de 0 a 0,5 seconde avec un repere a 0,2 seconde pour le point
- sous le bouton, une jauge "Temps restant avant fin de mot" descend de 2 secondes a 0 pendant l'inactivite, avec un repere a 1 seconde pour la prochaine lettre
- a droite, la moitie haute affiche le Morse saisi et la moitie basse affiche les mots decodes

La logique C++ utilise les durees par defaut suivantes :

- `dotDuration` : 200 ms
- `dashDuration` : 500 ms
- `letterGap` : 1000 ms
- `wordGap` : 2000 ms

Dans la fenetre graphique, chaque relachement ajoute un symbole Morse. Une pause de 1 seconde decode la lettre en cours, puis une pause de 2 secondes ajoute un espace entre deux mots.

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
