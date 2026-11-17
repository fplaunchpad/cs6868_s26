include Lockfree_list

module AMR = Atomic_markable_ref

(* Override add *)
let add list item =
  let key = Hashtbl.hash item in
  let rec attempt () =
    let (pred, curr) = locate list.head key in
    let node = { item = Some item; key; next = AMR.create curr false } in
    if AMR.compare_and_set pred.next
         ~expected_ref:curr
         ~new_ref:node
         ~expected_mark:false
         ~new_mark:false
    then true
    else attempt ()
  in
  attempt ()