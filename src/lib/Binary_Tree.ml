(* Michaël PÉRIN, Verimag / Université Grenoble-Alpes, Mars 2017
 *
 * CONTENT 
 *
 *   - Set of bit vectors represented as binary tree
 *   - Requires an instranciation of a Bit module defining Two_Values zero and unit
 *
 * USAGE
 *
 *   Requirement
 *    - Module  :  Bit_Vector.cmo
 *    - Library :
 *   Compilation:  ocamlc      Bit_Vector.cmo Binary_Tree.ml
 *   Interpreter:  ledit ocaml MyList.cmo MyString.cmo Tricks.cmo Pretty.cmo Bit_Vector.cmo Binary_Tree.cmo
 *
 * DEMO 
 *
 *   at end of the this file
 *)
    
type binaryTree =
  | NilTree
  | BinTree of binaryTree * binaryTree
             

             
module Made_Of =
  functor (Bit : Bit_Vector.Two_Values_Sig) ->
  struct
    
    type t = binaryTree
           
    type bit = Bit.t
    type word = bit list

    let rec depth: t -> int = function
      | NilTree -> 0
      | BinTree(l,r) -> 1 + max (depth l) (depth r)
              
    let rec union: t -> t -> t = fun bt1 bt2 ->
      match bt1,bt2 with
      | NilTree, _ -> bt2
      | _ , NilTree -> bt1
      | BinTree(l1,r1), BinTree(l2,r2) -> BinTree(union l1 l2, union r1 r2)
                                        
                                        
    let rec make_from: bit list -> t = fun bits ->
      match bits with
      | [] -> BinTree(NilTree,NilTree)
      | b::bs ->
         if b=Bit.zero
         then BinTree(make_from bs, NilTree)
         else BinTree(NilTree, make_from bs)
        
        
    let add_to: t -> bit list -> t = fun btree bits ->
      union btree (make_from bits)
      
      
    let build_from: word list -> binaryTree = fun words ->
      List.fold_left add_to NilTree words
      
    (* FROM binary tree TO set of words *)
      
    let distrib: 'a -> ('a list) list -> ('a list) list = fun bit words ->
      List.map (fun word -> bit::word) words

    let rec to_words: t -> word list = fun btree ->
      let epsilon = []
      in match btree with
         | NilTree -> []
         | BinTree(NilTree,NilTree) -> [ epsilon ]
         | BinTree(l_tree,r_tree)
           -> (distrib Bit.zero (to_words l_tree)) @ (distrib Bit.unit (to_words r_tree))

    (* FROM binary tree TO graph *)

    type label =
      | Any
      | Bit of bit

    let zero:label = Bit Bit.zero
    let unit:label = Bit Bit.unit                   
             
    type 'node edge = 'node * label * 'node
    type 'node edges = ('node edge) list
    type 'node graph = 'node * 'node edges (* graph = (entry_node, edges) *)
                     
    let make_edge: 'node -> label -> 'node graph option  -> 'node graph option = fun new_node label graph ->
      match graph with
      | None -> None
      | Some(entry_node,edges) -> Some (new_node, (new_node, label, entry_node) :: edges)
                                
    let merge_optional_graph: 'node graph option -> 'node graph option -> 'node graph option = fun og1 og2 ->
      match og1, og2 with
      | None, og2 -> og2
      | og1, None -> og1
      | Some(g1_entry_node, g1_edges), Some(g2_entry_node, g2_edges) when g1_entry_node = g2_entry_node
        -> Some(g1_entry_node, g1_edges @ g2_edges)
         
         
    let to_graph_with
          (mk_node_from  : 'node -> label -> 'node)
          (initial_node  : 'node)
          (opt_final_node: 'node option)
          (btree         : t)
        : 'node edges 
      = let rec to_graph_rec: 'node -> t -> 'node graph option = fun current_node btree ->
          match btree with
          | NilTree -> None
                     
          | BinTree(NilTree,NilTree)
            -> (match opt_final_node with
                | None            -> Some(current_node,[])
                | Some final_node -> Some(final_node, [])
               )
             
          | BinTree(l_tree,r_tree)
            ->
             let l_root_node = mk_node_from current_node (Bit Bit.zero)
             and r_root_node = mk_node_from current_node (Bit Bit.unit)
             in merge_optional_graph
                  (make_edge current_node (Bit Bit.zero) (to_graph_rec l_root_node l_tree))
                  (make_edge current_node (Bit Bit.unit) (to_graph_rec r_root_node r_tree))
              
        in match to_graph_rec initial_node btree with
           | None -> []
           | Some(_,edges) -> edges



    let to_complete_graph_with
          (mk_node_from  : 'node -> label -> 'node)
          (initial_node  : 'node)
          (accept_node   : 'node)
          (reject_node   : 'node)
          (btree         : t)
        : 'node edges 
      =
      let max_depth = (depth btree)-1 in
      let rec to_complete_graph_rec: int -> 'node -> t -> 'node graph option = fun current_depth current_node btree ->
          match btree with
          | NilTree
            -> if current_depth = max_depth
               then Some(reject_node, [])
               else let new_node = mk_node_from current_node Any
                    in make_edge current_node Any (to_complete_graph_rec (current_depth+1) new_node btree)
               
          | BinTree(NilTree,NilTree)
            -> Some(accept_node,[])
                            
          | BinTree(l_tree,r_tree)
            -> let l_root_node = mk_node_from current_node (Bit Bit.zero)
               and r_root_node = mk_node_from current_node (Bit Bit.unit)
               and d = current_depth + 1
               in merge_optional_graph
                    (make_edge current_node (Bit Bit.zero) (to_complete_graph_rec d l_root_node l_tree))
                    (make_edge current_node (Bit Bit.unit) (to_complete_graph_rec d r_root_node r_tree))
              
        in match to_complete_graph_rec 0 initial_node btree with
           | None -> []
           | Some(_,edges) -> edges


  end


(* DEMO

open Binary_Tree
open Binary_Tree.Demo
open Binary_Tree.Demo.BTree
let _ = Binary_Tree.Demo.demo()
m 
*)
  
module Demo =
  struct

    module Bit =
      struct
        type t = int
        let (zero:t) = 0
        let (unit:t) = 1
        let (pretty: t -> string) = string_of_int
      end

    module BTree = Made_Of(Bit)
                      
    type node =
      | W of char list
      | A
      | R
      
    let make_node_from: node -> BTree.label -> node = fun node label ->
      let char = match label with
        | BTree.Any     -> '?'
        | BTree.Bit bit -> if bit=Bit.zero then '0' else '1'
      in  match node with
          | W chars -> W (chars @ [char])
          | A -> A
          | R -> R

    let demo: unit -> 'a = fun () ->
      let z = Bit.zero
      and u = Bit.unit
      in let words = [[z;u;z]] (*;[z;u;z];[z;z];[u;u;z];[u;z]]*)
         in
         let btree = BTree.build_from words
         and initial_node = W []
         and accept_node  = A 
         and reject_node  = R 
         and opt_final_node = None
         in
         (List.map BTree.make_from words,
          btree,
          BTree.to_words btree,
          BTree.to_graph_with make_node_from
            initial_node
            opt_final_node
            btree,
          BTree.depth btree,
          BTree.to_complete_graph_with make_node_from
            initial_node
            accept_node
            reject_node
            btree
         )
  end
    
