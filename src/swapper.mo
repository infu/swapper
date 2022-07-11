import Result "mo:base/Result";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Nat32 "mo:base/Nat32";

import HashMap "mo:base/HashMap";
import Standard "./lib/standard";
import Lib "./lib/lib";

// License: Apache 2.0

// Status: Beta - untested

// Credits:
// Swapper - Anvil/ infu@nftanvil.com
// Aviate labs libraries - https://github.com/aviate-labs
// Sha224 library - https://github.com/flyq/motoko-sha224

shared({caller = _installer}) actor class Swapper() : async Lib.Swapper = this {

  type OrderId = Nat32;
  let FEE :Nat64 = 10000;

  private var nextOrderId: OrderId = 0;
  private let orderBook = HashMap.HashMap<OrderId, Order>(8, Nat32.equal, func (x:Nat32) {x});

  type BoxRequirements = {
    caller:Principal;
    ledger:Principal; // token ledger
    count:Nat64; // token balance
  };

  type Box = {
    account_id: Lib.AccountIdentifier;
    subaccount: Lib.SubAccount;
    requirements: BoxRequirements;
  };

  type BoxStatus = {
    #waiting;
    #loaded;
    #matching;
    #mismatch;
  };

  type OrderStatus = {
    var maker_box: BoxStatus;
    var taker_box: BoxStatus;
    var canceled: Bool;
  };

  type OrderState = {
    #locked;
    #swapped;
    #refund;
  };

  type OrderInfo = {
    maker : Box;
    taker : Box;
  };

  type Order = {
    info: OrderInfo;
    status: OrderStatus;
  };


  public shared func make(makerRequirements: BoxRequirements, takerRequirements: BoxRequirements) : async Result.Result<OrderInfo, Text> {
    nextOrderId += 1;
    let orderId = nextOrderId;

    let maker_subaccount = Lib.SubAccount.fromNat(Nat32.toNat( (orderId*2)+0) );
    let taker_subaccount = Lib.SubAccount.fromNat(Nat32.toNat( (orderId*2)+1) );

    let orderInfo:OrderInfo = {
      maker = {
        account_id = Lib.AccountIdentifier.fromPrincipal(Principal.fromActor(this), ?maker_subaccount);
        subaccount = maker_subaccount;
        requirements = makerRequirements;
        var status = #waiting;
      };
      taker = {
        account_id = Lib.AccountIdentifier.fromPrincipal(Principal.fromActor(this), ?taker_subaccount);
        subaccount = taker_subaccount;
        requirements = takerRequirements;
        var status = #waiting;
      };
      var canceled = false;
    };

    let orderStatus : OrderStatus = {
      var maker_box = #waiting;
      var taker_box = #waiting;
      var canceled = false;
    };

    let order = {
      info = orderInfo;
      status = orderStatus;
    };

    orderBook.put(orderId, order);
 
    #ok(orderInfo);
  };

  public query func info(orderId: OrderId) : async Result.Result<OrderInfo, Text> {
     switch(orderBook.get(orderId)) {
       case (?{info; status}) {
         #ok(info)
       };
       case (_) {
          #err("Order not found");
       }
     }
  };

  public shared({caller}) func transfer(orderId: OrderId, target: Lib.AccountIdentifier) : async Result.Result<(), Text> {
    switch(orderBook.get(orderId)) {
        case (?{info; status}) {
            switch(getOrderState(status)) {
                case (#swapped) {

                  if (info.maker.requirements.caller == caller) {
                    await transferBalance(info.taker, target);
                  } else if (info.taker.requirements.caller == caller) {
                    await transferBalance(info.maker, target);
                  } else return #err("Not called by maker or taker");

                  #ok();
                };
                case (#refund) {

                  if (info.maker.requirements.caller == caller) {
                    await transferBalance(info.maker, target);
                  } else if (info.taker.requirements.caller == caller) {
                    await transferBalance(info.taker, target);
                  } else return #err("Not called by maker or taker");

                  #ok();
                };
                case (#locked) {
                  return #err("Transfers locked");
                };
            };
        };
        case (_) {
           #err("Order not found");
        };
    }
  };

  public shared({caller}) func notify(orderId: OrderId) : async Result.Result<(), Text> {
      switch(orderBook.get(orderId)) {
        case (?{info; status}) {
            switch(getOrderState(status)) {
                case (#locked) {

                  if (info.maker.requirements.caller == caller) {
                    status.maker_box := await verifyBalance(info.maker);
                  } else if (info.taker.requirements.caller == caller) {
                    status.taker_box := await verifyBalance(info.taker);
                  } else return #err("Not called by maker or taker");

                   #ok();
                };
                case (#swapped) {
                   #err("No change / swapped");
                };
                case (#refund) {
                   #err("No change / refund");
                };
            };
         
        };
        case (_) {
           #err("Order not found");
        };
      };

  };

  public shared({caller}) func cancel(orderId: OrderId) : async Result.Result<(), Text> {
     switch(orderBook.get(orderId)) {
        case (?{info; status}) {
              if (info.maker.requirements.caller != caller and info.taker.requirements.caller != caller) return #err("Not maker or taker");
              status.canceled := true;
              #ok();
        };
         case (_) {
           #err("Order not found");
        };
      };
  };

  private func transferBalance (box: Box, target:Lib.AccountIdentifier) : async () {
      let ledger_actor = actor(Principal.toText(box.requirements.ledger)): Standard.Interface;

      let balance = await ledger_actor.transfer({
            account = box.account_id;
            memo = 0;
            amount = {e8s = box.requirements.count};
            fee = {e8s = FEE};
            from_subaccount = ?box.subaccount;
            to = target;
            created_at_time = null;
        });

  };


  // -- private func 
  private func getOrderState (status: OrderStatus) : OrderState {
    if (status.canceled or status.maker_box == #mismatch or status.taker_box == #mismatch) return #refund;
    if (status.maker_box == #matching and status.taker_box == #matching and status.canceled == false) return #swapped;
    return #locked;
  };

  private func verifyBalance (box: Box) : async BoxStatus {
      let ledger_actor = actor(Principal.toText(box.requirements.ledger)): Standard.Interface;
      let balance = await ledger_actor.account_balance({account = box.account_id});
      if (balance.e8s == box.requirements.count + FEE) return #matching else return #mismatch;
      // Parties need to add FEE to whatever box requirements are. 

  };


};
