#n
1s/.*/\
    Bin:1\
    figures!\
    board!\
    repeat?\
    estimate-black-king!\
    log!\
    del!\
    input!\
    step!\
    board!\
    count-pieces!\
    repeat-end!\
/
# переформатирование команд
1s/ *//g; 1s/\n/ /g; 1s/^ //

# обработка поступающей команды
1!{
    /^[a-h][1-8] *[a-h][1-8]$/ {
        # добавляем полученные значения впереди стека исполнения
        G; s/\n/ /
        # переходим на исполнение команд
        b @
    }

    # игрок хочет выйти
    /^q/ q

    # введена какая-то ерунда, стираем и возвращаем стек команд
    i\
    [12H[J[1A
    s/.*//

    g
    b
}

:@

/[a-z][a-z-]*[!?]/ {
    s//@&/

    # убрать верхнее значение
    /@del! */ {
        s///
        s/^[^ ]* *//
        b @
    }

    # повтор, пока на вершине не пустое
    /@repeat\? */ {
        /Bin:1* */ {
            s///
            s/@repeat\? \(.*\)repeat-end!/\1repeat\? \1repeat-end! */

            b @
        }
        s/Bin:[^ ]* *//

        b @
    }

    # дублирование первого значения
    /@dup! */ {
        s///
        s/[^ ]*/& &/

        b @
    }

    # ввод данных
    /@input! */ {
        s///; h; b
    }

    # генерация начального состояния доски
    /@figures! */ {
        # формат: XYFig
        # координаты белых тут и дальше должны идти НИЖЕ чёрных
        # БОЛЬШИЕ — чёрные, маленькие — белые
        s//Board:\
a8Rb8Nc8Id8Qe8Kf8Ig8Nh8R\
a7Pb7Pc7Pd7Pe7Pf7Pg7Ph7P\
a6 b6 c6 d6 e6 f6 g6 h6 \
a5 b5 c5 d5 e5 f5 g5 h5 \
a4 b4 c4 d4 e4 f4 g4 h4 \
a3 b3 c3 d3 e3 f3 g3 h3 \
a2pb2pc2pd2pe2pf2pg2ph2p\
a1rb1nc1id1qe1kf1ig1nh1r /
# пробел в конце нужен!

        s/\n//g

        b @
    }

    # вывод доски
    /@board! */ {
        s///
        # сохраняем стек команд
        h
        # убираем всё, кроме доски
        s/.*Board://
        s/ .*$//
        # расшифровываем доску
        # Pawn, Queen, King, bIshop, kNight, Rook
        y/pqkinrPQKINR12345678abcd/♟♛♚♝♞♜♙♕♔♗♘♖987654323579/
        s/\([1-9e-h]\)\([1-9]\)\(.\)/[\2;\1H\3 /g

        # расцвечиваем
        s/[8642];[37eg]H/&[48;5;209;37;1m/g
        s/[9753];[37eg]H/&[48;5;94;37;1m/g
        s/[8642];[59fh]H/&[48;5;94;37;1m/g
        s/[9753];[59fh]H/&[48;5;209;37;1m/g

        # двузначные числа
        s/e/11/g;s/f/13/g;s/g/15/g;s/h/17/g

        s/$/[0m[11H/
        # выводим доску и возвращаем всё как было
        i\
[2J[1;3Ha b c d e f g h\
8\
7\
6\
5\
4\
3\
2\
1\
\
Enter command:
        p
        g

        b @
    }

    # делаем ход по введённым пользователем данным
    /@step! */ {
        s///

        # гарды основных регулярок (их нужно тщательно защищать от несрабатываний,
        # иначе sed выдаст ошибку и остановится)
        # вычищаем всё, кроме доски и первых двух значений
        h; s/\([^ ]*\) \([^ ]*\).*Board:\([^ ]*\).*/\1 \2 \3/
        
        # выделяем указанные клетки
        s/\([^ ]*\) [^ ]* .*\(\1.\)/&(1:\2)/
        s/[^ ]* \([^ ]*\) .*\(\1.\)/&(2:\2)/
        # теперь они имеют формат:
        # номер_по_порядку_ввода:XYФигура
        s/.*(\(.....\)).*(\(.....\)).*/\1 \2/

        # теперь надо проверить:
        # 1. что берём не чужую и не пустую фигуру
        /1:..[PQKINR ]/ {
            g; s/[^ ]* [^ ]* *//; b @
        }

        # 2. не кладём на место своей фигуры
        /2:..[pqkbnr]/ {
            g; s/[^ ]* [^ ]* *//; b @
        }

        # если ход будет вперёд…
        /2:.*1:/ {
            g
            /\([^ ]*\) \([^ ]*\) \(.*Board:[^ ]*\2\).\([^ ]*\1\)\([pqkbnr]\)/ {
                s//\3\5\4 /
                b @
            }
        }

        # ход назад
        g
        s/\([^ ]*\) \([^ ]*\) \(.*Board:[^ ]*\1\)\([pqkbnr]\)\([^ ]*\2\)./\3 \5\4/
        b @
    }

    # количество оставшихся фигур
    /@count-pieces! */ {
        s///
        h
        # убираем всё, кроме доски
        s/.*Board://
        s/ .*$//
        # убираем всё, кроме белых фигур
        s/[^pqkbnrPQKINR]//g
        # считаем
        s/./1/g; s/^/Bin:/
        # возвращаем стек команд
        G
        # после G появился перевод строки, убираем его
        s/\n/ /

        b @
    }

    #оценочная функция имеющихся чёрных фигур
    /@estimate-black-pieces! */ {
        # пешка — 100, слон и конь — 300, ладья — 500, ферзь — 900

        # очистка всего лишнего
        s///; h; s/.*Board://; s/ .*$//
        # убираем всё, кроме подсчитываемых фигур
        s/[^PINRQ]//g
        # считаем количество * коэффициент фигуры (ферзь Q — единственный)
        s/P/1::/g; s/[IN]/111::/g; s/R/11111::/g; s/Q/111111111::/; s/^/Bin:/
        # добавляем к сохранённому стеку
        G; s/\n/ /

        b @
    }

    #для отладки: вывод текущего стека
    /@log! */ {
        s///
        l
        b @
    }

    #оценочная функция для позиции чёрных пешек
    /@estimate-black-pawn! */ {
        # очистка всего лишнего
        s///; h; s/.*Board://; s/ .*$//
        # оставляем только чёрные и белые пешки, перекодируем их в понятные координаты
        # теперь пешки записаны вот так: XЦвет (где Цвет — Black или White), разделены пробелом
        s/[a-h][1-8][^Pp]//g; y/Ppabcdefgh/WB12345678/; s/\([1-8]\)[1-8]/ \1/g

        # → Этап 1
        # ищем чёрные пешки, на вертикали у которых стоят белые, координаты белых идут
        # всегда ПЕРЕД координатами чёрных
        :estimate-black-pawn::black
        /\([1-8]\)W\(.*\1\)B/ {
            s//\1W\2b/
            b estimate-black-pawn::black
        }

        # → Этап 2.1
        # переводим координаты в последовательности длины X
        :estimate-black-pawn::x
        /[2-8]/ {
            s/[2-8]/1&/g
            y/2345678/1234567/

            b estimate-black-pawn::x
        }

        # → Этап 2.2
        # ищем пешки, не отсеянные на этапе 1, у которых на соседней линии слева стоят белые
        :estimate-black-pawn::left
        /\( 1*\)W\(.*\11\)B/ {
            s//\1W\2b/
            b estimate-black-pawn::left
        }

        # → Этап 2.3
        # ищем пешки, не отсеянные на этапе 2, у которых на соседней линии справа стоят белые
        :estimate-black-pawn::right
        / 1\(1*\)W\(.* \1\)B/ {
            s// 1\1W\2b/
            b estimate-black-pawn::right
        }

        # В итоге, W — белые пешки, b — чёрные, B — чёрные свободные пешки
        # избавляемся от несвободных и белых пешек
        s/ [^ ]*[Wb]//g

        # → Этап 3
        # считаем стоимости чёрных свободных пешек
        s/ 1B//; s/ 11B/ ::11111B/; s/ 111B/ :1:B/; s/ 1111B/ :1:11111B/; s/ 11111B/ :11:B/
        s/ 111111B/ :111:B/; s/ 1111111B/ 1:1111:B/; s/ 11111111B//

        # → Этап 4
        # сохраняем полученное, грузим стек обратно, вырезаем доску и оставляем чёрные пешки с координатами
        G; h; s/.*Board://; s/ .*$//; s/[a-h][1-8][^p]//g

        # оцениваем позиции всех пешек
        s/.[81]p/::B/g

        s/[abcfgh]7p/::1111B/g; s/[de]7p/::B/g

        s/[ah][65]p/::111111B/g; s/[bg][65]p/::11111111B/g; s/[cf]6p/::11B/g; s/[de]6p/:1:B/g

        s/[bg]5p/:1:11B/g; s/[cf]5p/:1:111111B/g; s/[de]5p/:11:1111B/g

        s/[ah]4p/::11111111B/g; s/[bg]4p/:1:11B/g; s/[cf]4p/:1:111111B/g; s/[de]4p/:11:1111B/g

        s/[ah][32]p/:1:11B/g; s/[bg][32]p/:1:111111B/g; s/[cf][32]p/:11:1111B/g; s/[de][32]p/:111:11B/g

        # вставляем пробелы между оценками
        s/B/& /g; s/^/ /

        # → Этап 5
        # возвращаем сохранённые оценки, убираем остатки стека
        G; s/\n\(.*\)\n.*/ \1/

        # → Этап 6
        # теперь у нас есть позиционные оценки свободных чёрных пешек и оценки всех чёрных пешек
        # нужно их сложить
        s/$/ :::S/

        :estimate-black-pawn::shift
        /11*B/ {
            # сложение разряда
            :estimate-black-pawn::sum
            /11*B/ {
                s/\(11*\)B\(.*\)\(1*\)S/B\2\1\3S/
                s/:1111111111\(1*\)S/1:\1S/

                b estimate-black-pawn::sum
            }

            # сдвиг разряда
            s/:B/B/g; s/:\(1*\)S/S \1:/

            b estimate-black-pawn::shift
        }

        s/:\(1*\)S/S \1:/

        # нормализация числа: сотни:десятки:единицы
        # на этом этапе неоткуда появиться тысячам — максимальная сумма 388
        s/[^:1]//g; s/:$//; s/^/Bin:/

        # добавляем к сохранённому стеку, вычищаем наш мусор, который мы складывали выше —
        # там второй строкой лежат оценки
        G; s/\n.*\n/ /

        b @
    }

    #оценочная функция для позиции чёрного короля
    /@estimate-black-king! */ {
        s///; h; s/.*Board://; s/ .*$//

        # выделяем короля
        s/[a-h][1-8][^k]//g

        # считаем его вес (матрица конца игры)
        s/[ah][18]./::/
        
        s/[de][54]./:111:111111/
        
        s/[cf][54]./:111:/; s/[de][63]./:111:/

        s/[bg][54]./:11:1111/; s/[de][72]./:11:1111/; s/[cf][63]./:11:1111/

        s/[de][18]./:1:11111111/; s/[ah][54]./:1:11111111/; s/[cf][72]./:1:11111111/; s/[bg][63]./:1:11111111/

        s/[bg][72]./:1:11/; s/[ah][63]./:1:11/; s/[cf][81]./:1:11/

        s/[a-h][1-9]./::111111/

        s/^/Bin:/; G; s/\n/ /

        b @
    }

    #оценочная функция для позиции чёрного коня
    /@estimate-black-knight! */ {
        s///; h; s/.*Board://; s/ .*$//

        # выделяем коней
        s/[a-h][1-8][^n]//g

        # считаем их вес
        s/[ah][18]./::B/g
        
        s/[de][54]./:111:11B/g
        
        s/[cf][54]./:11:11111111B/g; s/[de][63]./:11:11111111B/g

        s/[cf][36]./:11:1111B/g

        s/[bg][54]./:11:B/g; s/[de][72]./:11:B/g; s/[cf][63]./:11:B/g

        s/[de][18]./:1:B/g; s/[ah][54]./:1:B/g; s/[cf][72]./:1:B/g; s/[bg][63]./:1:B/g

        s/[bg][72]./::11111111B/g; s/[ah][63]./::11111111B/g; s/[cf][81]./::11111111B/g

        s/[a-h][1-9]./::1111B/

        # складываем веса
        :estimate-black-knight::shift
        /11*B/ {
            :estimate-black-knight::sum
            /11*B/ {
                s/\(11*\)B\(.*\)\(1*\)S/B\2\1\3S/; s/:1111111111\(1*\)S/1:\1S/
                b estimate-black-knight::sum
            }
            s/:B/B/g; s/:\(1*\)S/S \1:/
            b estimate-black-knight::shift
        }

        s/^/Bin:/; G; s/\n/ /

        b @
    }

    #оценочная функция для позиции чёрного слона
    /@estimate-black-bishop! */ {
        s///; h; s/.*Board://; s/ .*$//

        # выделяем слонов
        s/[a-h][1-8][^i]//g

        # считаем их вес
        s/[a-h][81]./:1:1111B/g; s/[ah][1-8]./:1:1111B/g

        s/[bg][72]./:11:11B/g; s/[c-f][3-6]/:11:11B/g

        s/[a-h][1-9]./:1:11111111B/g

        # складываем веса
        :estimate-black-bishop::shift
        /11*B/ {
            :estimate-black-bishop::sum
            /11*B/ {
                s/\(11*\)B\(.*\)\(1*\)S/B\2\1\3S/; s/:1111111111\(1*\)S/1:\1S/
                b estimate-black-bishop::sum
            }
            s/:B/B/g; s/:\(1*\)S/S \1:/
            b estimate-black-bishop::shift
        }

        s/^/Bin:/; G; s/\n/ /

        b @
    }
}

b @