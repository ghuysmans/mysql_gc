let () =
  let c = Mysql.quick_connect () in
  let open Mysql.Prepared in
  let s = create c "SELECT 1" in
  let p = execute s [| |] in
  Gc.minor ();
  ignore @@ fetch p
