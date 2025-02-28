# Project: Snake Game with Two Led Matrix
## Other note
This application is base on `Project: Snake Game with one Led matrix`. In this project, we just change the data structure of the State of Gen Server, we add one variable which defines which led we should use to display and handle some cases when the Snake reaches the border. You can read the README file in `../snake_game` to get more detail about Snake Game.
## Schematic
![](../snake_game_2led/assets/SchematicSnakeGame.png)
![](../snake_game_2led/assets/snake_game.png)


# Ma trận LED 8x8

|   | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|---|
| **7** | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| **6** | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| **5** | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| **4** | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| **3** | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| **2** | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| **1** | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| **0** | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |


snakehead:
```
{LED_MATRIX(0-1), {X(0-7), Y(0-7)}}
eg: {0,{7,7}}
```

snakebody:
```
#{LENGTH_SNAKE_NUMBER(0-realtime_snake_length) => {LED_MATRIX(0-1),{X(0-7), Y(0-7)}}

bien State1: {snake,<0.3.0>,{0,{7,7}},#{0 => {0,{7,4}},1 => {0,{7,5}},2 => {0,{7,6}},3 => {0,{7,7}}},4,{0,{1,6}},#{1 => 0,2 => 2,3 => 0,4 => 0,5 => 0,6 => 0,7 => 0,8 => 15},#{1 => 0,2 => 0,3 => 0,4 => 0,5 => 0,6 => 0,7 => 0,8 => 0},{0,1},false,undefined}
bien State1: {snake,<0.3.0>,{0,{7,0}},#{0 => {0,{7,5}},1 => {0,{7,6}},2 => {0,{7,7}},3 => {0,{7,0}}},4,{0,{1,6}},#{1 => 0,2 => 2,3 => 0,4 => 0,5 => 0,6 => 0,7 => 0,8 => 135},#{1 => 0,2 => 0,3 => 0,4 => 0,5 => 0,6 => 0,7 => 0,8 => 0},{0,1},false,undefined}
bien State1: {snake,<0.3.0>,{0,{7,1}},#{0 => {0,{7,6}},1 => {0,{7,7}},2 => {0,{7,0}},3 => {0,{7,1}}},4,{0,{1,6}},#{1 => 0,2 => 2,3 => 0,4 => 0,5 => 0,6 => 0,7 => 0,8 => 195},#{1 => 0,2 => 0,3 => 0,4 => 0,5 => 0,6 => 0,7 => 0,8 => 0},{0,1},false,undefined}
bien State1: {snake,<0.3.0>,{0,{7,2}},#{0 => {0,{7,7}},1 => {0,{7,0}},2 => {0,{7,1}},3 => {0,{7,2}}},4,{0,{1,6}},#{1 => 0,2 => 2,3 => 0,4 => 0,5 => 0,6 => 0,7 => 0,8 => 225},#{1 => 0,2 => 0,3 => 0,4 => 0,5 => 0,6 => 0,7 => 0,8 => 0},{0,1},false,undefined}
bien State1: {snake,<0.3.0>,{0,{7,3}},#{0 => {0,{7,0}},1 => {0,{7,1}},2 => {0,{7,2}},3 => {0,{7,3}}},4,{0,{1,6}},#{1 => 0,2 => 2,3 => 0,4 => 0,5 => 0,6 => 0,7 => 0,8 => 240},#{1 => 0,2 => 0,3 => 0,4 => 0,5 => 0,6 => 0,7 => 0,8 => 0},{0,1},false,undefind}
bien State1: {snake,<0.3.0>,{0,{7,4}},#{0 => {0,{7,1}},1 => {0,{7,2}},2 => {0,{7,3}},3 => {0,{7,4}}},4,{0,{1,6}},#{1 => 0,2 => 2,3 => 0,4 => 0,5 => 0,6 => 0,7 => 0,8 => 120},#{1 => 0,2 => 0,3 => 0,4 => 0,5 => 0,6 => 0,7 => 0,8 => 0},{0,1},false,undefined}
bien State1: {snake,<0.3.0>,{0,{7,5}},#{0 => {0,{7,2}},1 => {0,{7,3}},2 => {0,{7,4}},3 => {0,{7,5}}},4,{0,{1,6}},#{1 => 0,2 => 2,3 => 0,4 => 0,5 => 0,6 => 0,7 => 0,8 => 60},#{1 => 0,2 => 0,3 => 0,4 => 0,5 => 0,6 => 0,7 => 0,8 => 0},{0,1},false,undefined}
bien State1: {snake,<0.3.0>,{0,{7,6}},#{0 => {0,{7,3}},1 => {0,{7,4}},2 => {0,{7,5}},3 => {0,{7,6}}},4,{0,{1,6}},#{1 => 0,2 => 2,3 => 0,4 => 0,5 => 0,6 => 0,7 => 0,8 => 30},#{1 => 0,2 => 0,3 => 0,4 => 0,5 => 0,6 => 0,7 => 0,8 => 0},{0,1},false,undefined}

```

snakelen: length of snake, default is 2

food:
```
{LED_MATRIX(0-1), {X(0-7), Y(0-7)}}
eg: {0,{1,6}}
```

data1: matrix map of matrix led 1
data2: matrix map of matrix led 2
```
#{COLUNM(1-8) => 8_BITS_BINARY_NUMBER}
eg:
#{1 => 0,2 => 2,3 => 0,4 => 0,5 => 0,6 => 0,7 => 0,8 => 30}
```

direction:
```
{ 1, 0}: forward
{-1, 0}: backward
{0,  1}: up
{0, -1}: down
```