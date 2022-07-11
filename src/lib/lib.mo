import SHA224 "./SHA224";
import Binary "mo:encoding/Binary";
import Blob "mo:base/Blob";
import Hash "mo:base/Hash";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Array "mo:base/Array";
import Principal "mo:principal/Principal";
import CRC32 "mo:hash/CRC32";

module {

        public type Swapper = actor {

        };
 

        public type AccountIdentifier = Blob; //32 bytes
        public type SubAccount = Blob; //32 bytes

        public module AccountIdentifier = {
            private let prefix : [Nat8] = [10, 97, 99, 99, 111, 117, 110, 116, 45, 105, 100];

            public func equal(a : AccountIdentifier, b : AccountIdentifier) : Bool {
                a == b
            };

            public func hash(accountId : AccountIdentifier) : Hash.Hash {
                CRC32.checksum(Blob.toArray(accountId));
            };

            public func fromPrincipal(p : Principal, subAccount : ?SubAccount) : AccountIdentifier {
                fromBlob(Principal.toBlob(p), subAccount);
            };

            public func fromBlob(data : Blob, subAccount : ?SubAccount) : AccountIdentifier {
                fromArray(Blob.toArray(data), subAccount);
            };

            public func fromArray(data : [Nat8], subAccount : ?SubAccount) : AccountIdentifier {
                let account : [Nat8] = switch (subAccount) {
                    case (null) { Array.freeze(Array.init<Nat8>(32, 0)); };
                    case (?sa)  { Blob.toArray(sa); };
                };
                
                let inner = SHA224.sha224(Array.flatten<Nat8>([prefix, data, account]));

                Blob.fromArray(Array.append<Nat8>(
                    Binary.BigEndian.fromNat32(CRC32.checksum(inner)),
                    inner,
                ));
            };


        };

        public module SubAccount = {
            public func fromNat(idx: Nat) : SubAccount {
                Blob.fromArray(Array.append<Nat8>(
                    Array.freeze(Array.init<Nat8>(24, 0)),
                    Binary.BigEndian.fromNat64(Nat64.fromNat(idx))
                    ));
                };
        };
}