# Présentation

Quand [la chaîne construite par `sprintf`](sqlgg/original.ml) est _trop longue_,
le programme _segfault_ :
```
$ dune exec ./sqlgg/original.exe
Segmentation fault (core dumped)
```

Environnement :
- Linux 4.19.101, **32 bits**
- [NixOS](https://nixos.org) 19.09.2008.ea553d8c67c
- [MariaDB](https://mariadb.org) 10.3.18
- [OCaml](https://ocaml.org) 4.06.1
- [ocaml-mysql](https://github.com/ygrek/ocaml-mysql) 1.2.4
- [mariadb-connector-c](https://github.com/mariadb-corporation/mariadb-connector-c) 3.1.5

# Enquête

## Reconnaissance
```
$ gdb _build/default/sqlgg/original.exe
GNU gdb (GDB) 8.3.1
Copyright (C) 2019 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
Type "show copying" and "show warranty" for details.
This GDB was configured as "i686-unknown-linux-gnu".
Type "show configuration" for configuration details.
For bug reporting instructions, please see:
<http://www.gnu.org/software/gdb/bugs/>.
Find the GDB manual and other documentation resources online at:
    <http://www.gnu.org/software/gdb/documentation/>.

For help, type "help".
Type "apropos word" to search for commands related to "word"...
Reading symbols from _build/default/sqlgg/original.exe...
(gdb) r
Starting program: _build/default/sqlgg/original.exe
[Thread debugging using libthread_db enabled]
Using host libthread_db library "/nix/store/7943wlbwhlmkcwmcgclvnf3y0y287j47-glibc-2.30/lib/libthread_db.so.1".

Program received signal SIGSEGV, Segmentation fault.
0xb7f9b783 in mysql_stmt_fetch ()
   from /nix/store/34pgf6g6fndg8h0gkhdinx5zmmjd03yl-mariadb-connector-c-3.1.5/lib/mariadb/libmariadb.so.3
(gdb) bt
#0  0xb7f9b783 in mysql_stmt_fetch ()
   from /nix/store/34pgf6g6fndg8h0gkhdinx5zmmjd03yl-mariadb-connector-c-3.1.5/lib/mariadb/libmariadb.so.3
#1  0x080a56f2 in caml_mysql_stmt_fetch (result=<optimized out>) at mysql_stubs.c:1165
#2  0x080734b7 in camlSqlgg_mysql__loop_1457 () at mysql.ml:646
#3  0x080732a3 in camlSqlgg_mysql__try_finally_1436 () at impl/ocaml/mysql/sqlgg_mysql.ml:129
#4  0x0807234a in camlDune__exe__Scan__columns_1344 () at sqlgg/scan.ml:95
#5  0x08071c95 in camlDune__exe__Original__entry () at sqlgg/original.ml:9
#6  0x0806eb9c in caml_program ()
#7  0x080bfd81 in caml_start_program ()
#8  0x080c0569 in caml_startup_common (argv=0xbfffcb94, pooling=<optimized out>) at startup.c:156
#9  0x080c05ba in caml_startup_exn (argv=0xbfffcb94) at startup.c:161
#10 0x080c05d8 in caml_startup (argv=0xbfffcb94) at startup.c:166
#11 0x080c0618 in caml_main (argv=0xbfffcb94) at startup.c:173
#12 0x0806e8c5 in main (argc=1, argv=0xbfffcb94) at main.c:44
(gdb) list
31      main.c: No such file or directory.
(gdb) disas
Dump of assembler code for function mysql_stmt_fetch:
   0xb7f9b730 <+0>:     push   %esi
   0xb7f9b731 <+1>:     push   %ebx
   0xb7f9b732 <+2>:     call   0xb7f87c70 <__x86.get_pc_thunk.bx>
   0xb7f9b737 <+7>:     add    $0x31591,%ebx
   0xb7f9b73d <+13>:    sub    $0x14,%esp
   0xb7f9b740 <+16>:    mov    %gs:0x14,%eax
   0xb7f9b746 <+22>:    mov    %eax,0xc(%esp)
   0xb7f9b74a <+26>:    xor    %eax,%eax
   0xb7f9b74c <+28>:    mov    0x20(%esp),%esi
   0xb7f9b750 <+32>:    mov    0x2c(%esi),%eax
   0xb7f9b753 <+35>:    cmp    $0x2,%eax
   0xb7f9b756 <+38>:    jbe    0xb7f9b848 <mysql_stmt_fetch+280>
   0xb7f9b75c <+44>:    mov    0x34(%esi),%edx
   0xb7f9b75f <+47>:    test   %edx,%edx
   0xb7f9b761 <+49>:    je     0xb7f9b848 <mysql_stmt_fetch+280>
   0xb7f9b767 <+55>:    cmp    $0x3,%eax
   0xb7f9b76a <+58>:    je     0xb7f9b830 <mysql_stmt_fetch+256>
   0xb7f9b770 <+64>:    cmp    $0x6,%eax
   0xb7f9b773 <+67>:    je     0xb7f9b8c8 <mysql_stmt_fetch+408>
   0xb7f9b779 <+73>:    sub    $0x8,%esp
   0xb7f9b77c <+76>:    mov    0x20(%esi),%eax
   0xb7f9b77f <+79>:    lea    0x10(%esp),%edx
=> 0xb7f9b783 <+83>:    mov    0x3b0(%eax),%eax
   0xb7f9b789 <+89>:    push   %edx
   0xb7f9b78a <+90>:    push   %esi
   0xb7f9b78b <+91>:    call   *0x34(%eax)
(gdb) p $eax
$1 = 0
```

On traverse une structure pointée par `eax` et il est `NULL`.
On finit par appeler un pointeur de fonction (dernière ligne).

Sans les sources, c'est difficile d'y voir plus clair et comme le connecteur
est _libre_, ça n'a pas de sens de se mettre à faire du _reverse_ !

## Symboles

Les symboles de debug ne sont pas inclus par défaut dans les bibliothèques
compilées par Nix. [Le wiki](https://nixos.wiki/wiki/Debug_Symbols) propose
de recompiler le connecteur :
```
$ nix-build -E 'with import <nixpkgs> {}; enableDebugging mariadb-connector-c'
```

_Si on voulait faire les choses comme il faut_, il faudrait recompiler les
bindings OCaml avec cette nouvelle version. Pour gagner du temps, supposons que
la seule différence est la présence des symboles de debug et modifions le chemin
directement dans l'exécutable.
Nix utilise déjà couramment `patchelf` pour ses builds _reproductibles_.
```
$ cp _build/default/sqlgg/original.exe original.exe
$ chmod +w original.exe
$ patchelf --print-rpath original.exe
/nix/store/anwyzipxv0s0pfi5x2am58m8ybci8faj-shell/lib:/nix/store/34pgf6g6fndg8h0gkhdinx5zmmjd03yl-mariadb-connector-c-3.1.5/lib/mariadb/:/nix/store/7943wlbwhlmkcwmcgclvnf3y0y287j47-glibc-2.30/lib:/nix/store/wmc8z9nzr1yca86lmz7y7aw1932a33cg-gcc-9.2.0-lib/lib
$ patchelf --set-rpath /nix/store/anwyzipxv0s0pfi5x2am58m8ybci8faj-shell/lib:result/lib/mariadb:/nix/store/7943wlbwhlmkcwmcgclvnf3y0y287j47-glibc-2.30/lib:/nix/store/wmc8z9nzr1yca86lmz7y7aw1932a33cg-gcc-9.2.0-lib/lib original.exe
```

On pourrait s'arrêter là mais pour bien voir ce qui se passe, téléchargeons les
sources du connecteur qu'on vient de recompiler. Pour ça, cherchons dans sa
dérivation le chemin vers l'archive qui les contient avant de la décompresser :
```
$ nix-store --query --deriver `readlink result`
/nix/store/g8blrawjkyk7rk7ax5hv0nk4sg7h4dsq-mariadb-connector-c-3.1.5.drv
$ nix show-derivation /nix/store/g8blrawjkyk7rk7ax5hv0nk4sg7h4dsq-mariadb-connector-c-3.1.5.drv |jq -r '.[].env.src'
/nix/store/xk0mc7vfwszx8rjszzigccjzw5nd5iva-mariadb-connector-c-3.1.5-src.tar.gz
$ cp /nix/store/xk0mc7vfwszx8rjszzigccjzw5nd5iva-mariadb-connector-c-3.1.5-src.tar.gz .
$ gzip -d xk0mc7vfwszx8rjszzigccjzw5nd5iva-mariadb-connector-c-3.1.5-src.tar.gz
$ tar xf xk0mc7vfwszx8rjszzigccjzw5nd5iva-mariadb-connector-c-3.1.5-src.tar
$ ls mariadb-connector-c-3.1.5-src/
appveyor.yml         client  CMakeLists.txt  examples  libmariadb      plugins  unittest  win-iconv
azure-pipelines.yml  cmake   COPYING.LIB     include   mariadb_config  README   win       zlib
```

Il ne reste plus qu'à relancer _gdb_ en lui indiquant où se trouvent les sources :
```
$ gdb ./original.exe
GNU gdb (GDB) 8.3.1
Copyright (C) 2019 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
Type "show copying" and "show warranty" for details.
This GDB was configured as "i686-unknown-linux-gnu".
Type "show configuration" for configuration details.
For bug reporting instructions, please see:
<http://www.gnu.org/software/gdb/bugs/>.
Find the GDB manual and other documentation resources online at:
    <http://www.gnu.org/software/gdb/documentation/>.

For help, type "help".
Type "apropos word" to search for commands related to "word"...
Reading symbols from ./original.exe...
(gdb) set substitute-path  /build/mariadb-connector-c-3.1.5-src/ mariadb-connector-c-3.1.5-src
(gdb) r
Starting program: original.exe
[Thread debugging using libthread_db enabled]
Using host libthread_db library "/nix/store/7943wlbwhlmkcwmcgclvnf3y0y287j47-glibc-2.30/lib/libthread_db.so.1".

Program received signal SIGSEGV, Segmentation fault.
0xb7f9f7bc in mysql_stmt_fetch (stmt=0x815b410)
    at /build/mariadb-connector-c-3.1.5-src/libmariadb/mariadb_stmt.c:1453
warning: Source file is more recent than executable.
1453      if ((rc= stmt->mysql->methods->db_stmt_fetch(stmt, &row)))
(gdb) p stmt->mysql
$1 = (MYSQL *) 0x0
```

Qui a fait ça ? Nos processeurs sont capables de surveiller les accès mémoire
et un débogueur peut les configurer pour interrompre le programme à chaque
modification.
On utilise `watch -l stmt->mysql` pour utiliser l'adresse de `stmt->mysql`,
sans quoi _gdb_ remarque la disparition de `stmt` à la sortie de la fonction.
```
$ gdb ./original.exe
GNU gdb (GDB) 8.3.1
Copyright (C) 2019 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
Type "show copying" and "show warranty" for details.
This GDB was configured as "i686-unknown-linux-gnu".
Type "show configuration" for configuration details.
For bug reporting instructions, please see:
<http://www.gnu.org/software/gdb/bugs/>.
Find the GDB manual and other documentation resources online at:
    <http://www.gnu.org/software/gdb/documentation/>.

For help, type "help".
Type "apropos word" to search for commands related to "word"...
Reading symbols from ./original.exe...
(gdb) b mysql_stmt_fetch
Breakpoint 1 at 0x806e800
(gdb) r
Starting program: original.exe
[Thread debugging using libthread_db enabled]
Using host libthread_db library "/nix/store/7943wlbwhlmkcwmcgclvnf3y0y287j47-glibc-2.30/lib/libthread_db.so.1".

Breakpoint 1, mysql_stmt_fetch (stmt=0x815b410)
    at /build/mariadb-connector-c-3.1.5-src/libmariadb/mariadb_stmt.c:1431
1431    /build/mariadb-connector-c-3.1.5-src/libmariadb/mariadb_stmt.c: No such file or directory.
(gdb) p stmt->mysql
$1 = (MYSQL *) 0x8158ae0
(gdb) watch -l stmt->mysql
Hardware watchpoint 2: -location stmt->mysql
(gdb) d 1
(gdb) c
Continuing.

Hardware watchpoint 2: -location stmt->mysql

Old value = (MYSQL *) 0x8158ae0
New value = (MYSQL *) 0x0
ma_invalidate_stmts (mysql=0x8158ae0, function_name=0xb7fb6cef "mysql_close()")
    at /build/mariadb-connector-c-3.1.5-src/libmariadb/mariadb_lib.c:1735
1735    /build/mariadb-connector-c-3.1.5-src/libmariadb/mariadb_lib.c: No such file or directory.
(gdb) bt
#0  ma_invalidate_stmts (mysql=0x8158ae0, function_name=0xb7fb6cef "mysql_close()")
    at /build/mariadb-connector-c-3.1.5-src/libmariadb/mariadb_lib.c:1735
#1  0xb7f9929b in mysql_close (mysql=0x8158ae0)
    at /build/mariadb-connector-c-3.1.5-src/libmariadb/mariadb_lib.c:1982
#2  0x080a2b09 in conn_finalize (dbd=-1215487080) at mysql_stubs.c:176
#3  0x080a9577 in caml_empty_minor_heap () at minor_gc.c:386
#4  0x080a9958 in caml_gc_dispatch () at minor_gc.c:443
#5  0x080a72fc in caml_garbage_collection () at signals_asm.c:78
#6  0x080bfc3e in caml_system.code_begin ()
#7  0x08093772 in camlCamlinternalFormat__fun_86307 () at camlinternalFormat.ml:1641
#8  0x08071945 in caml_apply5 ()
#9  0x08072427 in camlDune__exe__Scan__fun_1537 () at sqlgg/scan.ml:96
#10 0x080734cb in camlSqlgg_mysql__loop_1457 () at impl/ocaml/mysql/sqlgg_mysql.ml:142
#11 0x080732a3 in camlSqlgg_mysql__try_finally_1436 () at impl/ocaml/mysql/sqlgg_mysql.ml:129
#12 0x0807234a in camlDune__exe__Scan__columns_1344 () at sqlgg/scan.ml:95
#13 0x08071c95 in camlDune__exe__Original__entry () at sqlgg/original.ml:9
#14 0x0806eb9c in caml_program ()
#15 0x080bfd81 in caml_start_program ()
#16 0x080c0569 in caml_startup_common (argv=0xbfffcbc4, pooling=<optimized out>) at startup.c:156
#17 0x080c05ba in caml_startup_exn (argv=0xbfffcbc4) at startup.c:161
#18 0x080c05d8 in caml_startup (argv=0xbfffcbc4) at startup.c:166
#19 0x080c0618 in caml_main (argv=0xbfffcbc4) at startup.c:173
#20 0x0806e8c5 in main (argc=1, argv=0xbfffcbc4) at main.c:44
```

On remarque que c'est le ramasse-miettes (`caml_garbage_collection`) qui lance
le destructeur de la connexion (`conn_finalize`). Ce dernier finit par écraser
`stmt->mysql` via `ma_invalidate_stmts`.

Normalement, le destructeur ne devrait pas être appelé, la valeur devrait être
promue vers le _major heap_. Cela correspond à [ce qu'on trouve dans les sources
du _runtime_ OCaml](https://github.com/ocaml/ocaml/blob/4.06/byterun/minor_gc.c#L384).

À ce stade, nous ne savons pas si le bug se trouve dans les _bindings_ ou dans
le GC. Je pense _a priori_ que les _bindings_ sont en cause. Pour confirmer
cette hypothèse, je peux les comparer à d'autres.

## Reproduction
J'ai rencontré ce bug par chance : il ne se manifeste que lors d'un ramassage
déclenché par la consommation de mémoire liée au "grand" nombre de lignes dans
`information_schema.columns` :
```
$ mysql information_schema
MariaDB [information_schema]> select count(*) from columns;
+----------+
| count(*) |
+----------+
|     1781 |
+----------+
1 row in set (0.090 sec)
```

Je peux [provoquer ce bug](sqlgg/mini.ml) plus vite et partout en forçant un
ramassage dès la première ligne et en ne lisant plus les données d'une table.

_sqlgg_ est ici une dépendance qui complique inutilement le suivi de l'exécution
du programme. [test.ml](test.ml) fait la même chose, mais en 7 lignes et sans
aucune dépendance autre qu'_ocaml-mysql_.

## Atténuation
### Variable globale
Il y a plusieurs approches :
1. Rendre globale la variable `c`
2. Stocker globalement une `ref`.
### Ramassage préventif
On peut forcer un ramassage en appelant `Gc.minor` dans _main_.

## Tests d'intégration
### GitHub Actions
GitHub Actions repose sur un _runner_ implémenté avec .NET Core.
Cette plateforme n'est pas compatible avec GNU/Linux 32 bits.

En 64 bits, [il n'y a aucun problème](https://github.com/ghuysmans/mysql_gc/actions) !
C'est peut-être la raison pour laquelle on n'a pas remarqué ce bug plus tôt.
