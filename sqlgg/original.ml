module Db = Scan.Sqlgg (Sqlgg_mysql.Default)

let () =
  let c = Mysql.quick_connect ~database:"information_schema" () in
  begin match Sys.argv with
    | [| _; "-fix" |] -> Gc.minor () (* why? *)
    | _ -> ()
  end;
  Db.List.columns c (fun ~table_schema ~table_name ~column_name ~is_nullable ~column_type ->
    Printf.sprintf "%s.%s: %s %s%s"
      table_schema table_name column_name column_type
      (if is_nullable = "NO" then " NOT NULL" else "")
  ) |>
  List.iter print_endline
