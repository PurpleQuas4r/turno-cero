# Turno Cero 0.2

Abre el proyecto en Godot 4.7 y pulsa **F5**. En Windows, puedes indicar la ubicación de Godot al lanzador del proyecto con la variable `GODOT_EXE`. Usa las flechas y Enter, o haz clic, para elegir el nivel. El menú de pausa permite continuar, cambiar de nivel o salir.

## Niveles

- **Helipuerto.** Arena de azotea al atardecer. Caer por un borde cuenta como una derrota en la ronda. No hay cronómetro. Las armas reaparecen por turnos después de que su punto quede libre.
- **Sala de pruebas.** Pisa las placas para generar las armas. Cada placa comprueba el suelo y el inventario antes de generar otra copia. La mina colocada también cuenta. Vanta empieza quieto al otro lado de la sala. Si lo eliminas, la placa **VANTA IA** genera un rival que se acerca y golpea. Solo puede existir un Vanta.

## Controles

| Entrada | Acción |
| --- | --- |
| ← / → | Moverse o cambiar el lado de la mira |
| ↑ | Saltar. En una escalera, mantén ↑ para seguir subiendo. |
| ↓ | Agacharse o bajar por una escalera |
| Doble ← / → | Correr al mantener la segunda pulsación |
| ↓ mientras corres | Deslizarte |
| N | Golpear o cancelar el disparo al apuntar |
| ↓ + N | Recoger un objeto cercano |
| Mantener M | Apuntar. Ajusta la altura con ↑ y ↓. |
| M + coma (,) | Disparar o colocar la mina equipada |
| J | Recargar antes del último disparo. Al vaciar el cargador, el arma desaparece. |
| ↓ + J | Bloquear ataques cuerpo a cuerpo |
| Q | Lanzar el objeto equipado |
| Esc / F1 | Pausa / sonido |

## Combate

- Correr, saltar y bloquear consumen stamina. La AWP y el RPG también la consumen al llevarlos y multiplican por cinco el coste de correr y saltar.
- Al agotar la stamina, pierdes el control durante 3 segundos. Seis pulsaciones de las flechas acortan el aturdimiento en hasta 1 segundo.
- Un golpe cuerpo a cuerpo aturde durante 0,5 segundos. Hay un intervalo de 0,8 segundos entre ataques. Tres impactos seguidos derriban al luchador durante 1,5 segundos. Mientras está en el suelo es inmune a los golpes cuerpo a cuerpo.

## Armas

La vida y la stamina empiezan en 100. Mantener M y coma repite el disparo según el intervalo del arma. Los ángulos de precisión son la desviación máxima a cada lado de la mira.

| Arma | Daño | Cargador | Intervalo | Recarga | Precisión |
| --- | ---: | ---: | ---: | ---: | --- |
| 9mm | 10 | 8 | 0,45 s | 1,5 s | Media (±4°) |
| Glock | 6 | 12 | 0,08 s | 2 s | Muy baja (±12°) |
| MP5K | 8 | 20 | 0,15 s | 1,5 s | Media (±4°) |
| UZI | 5 | 32 | 0,08 s | 2 s | Baja (±8°) |
| AKM | 18 | 20 | 0,30 s | 2,5 s | Media (±4°) |
| M4 | 12 | 25 | 0,22 s | 2 s | Alta (±2°) |
| AWP | 80 | 3 | 2 s | 3,5 s | Muy alta (±0,6°) |
| RPG | 100 en área | 1 | Disparo único | — | Media (±4°) |
| Claymore | 75 en área | 1 | Colocación única | — | No aplica |

El arte activo de los personajes está en `stickman_art.gd`. Dibuja sobre una cuadrícula de 16 × 16 px y la muestra al doble de escala para conservar las proporciones en la arena. El arte anterior se conserva en `fighter_art.gd`.
