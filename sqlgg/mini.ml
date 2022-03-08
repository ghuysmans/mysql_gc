module Db = Scan.Sqlgg (Sqlgg_mysql.Default)

let () =
  let c = Mysql.quick_connect () in
  Db.crash c (fun ~x -> Gc.minor (); ignore x)
