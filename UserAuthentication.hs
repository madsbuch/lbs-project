{-# LANGUAGE DataKinds #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}


module UserAuthentication where

import Language 

{-
User authentication example.

First we deine a list of users, then we generate a function for
testing if a user is in that list
-}
--
hash pass = let
              multList = (Map pass (\count char -> Time char (Time count char)))
              folded = Fold multList (Lit (I 0)) (\_ a b -> Plus a b)
            in
              folded

-- "webbies"
user1Name = L (I 119 ::: I 101 ::: I 98 ::: I 98 ::: I 105 ::: I 101 ::: I 115 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: Nill)
-- "hunter2"
user1Pass = L (I 104 ::: I 117 ::: I 110 ::: I 116 ::: I 101 ::: I 114 ::: I 50 ::: I 0  ::: I 0  ::: I 0  ::: I 0  ::: I 0  ::: I 0  ::: I 0  ::: I 0  ::: I 0  ::: I 0  ::: I 0  ::: I 0  ::: I 0  ::: I 0  ::: I 0  ::: I 0  ::: I 0  ::: I 0  ::: I 0  ::: I 0  ::: I 0  ::: I 0  ::: I 0  ::: Nill)
user1 = (P (P user1Name (I 0)) user1Pass)

 -- "warlizard"
user2Name = L (I 119 ::: I 97 ::: I 114 ::: I 108 ::: I 105 ::: I 122 ::: I 122 ::: I 97 ::: I 114 ::: I 100 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: Nill)
 -- "password"
user2Pass = L (I 112 ::: I 97 ::: I 115 ::: I 115 ::: I 119 ::: I 111 ::: I 114 ::: I 100 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: Nill )
user2 = (P (P user2Name (I 1)) user2Pass)

 -- "Randall"
user3Name = L (I 82 ::: I 97 ::: I 110 ::: I 100 ::: I 97 ::: I 108 ::: I 108 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: I 0 ::: Nill)
 -- "common horse battery staple"
user3Pass = L (I 99 ::: I 111 ::: I 109 ::: I 109 ::: I 111 ::: I 110 ::: I 32 ::: I 104 ::: I 111 ::: I 114 ::: I 115 ::: I 101 ::: I 32 ::: I 98 ::: I 97 ::: I 116 ::: I 116 ::: I 101 ::: I 114 ::: I 121 ::: I 32 ::: I 115 ::: I 116 ::: I 97 ::: I 112 ::: I 108 ::: I 101 ::: I 0 ::: I 0 ::: I 0 ::: Nill)
user3 = (P (P user3Name (I 2)) user3Pass)

hashUser user = Pair (Fst user) (hash (Scn user))

hashedUsers = Map (Lit $ L (user1 ::: user2 ::: user3 ::: Nill)) (\_ user -> hashUser user)

equalIntList xs ys = Fold (Map (Zip xs ys) (\_ p -> IEq (Fst p) (Scn p))) (Lit (B True)) (\_ a b -> And a b)

testUser user name password = And (equalIntList (Fst (Fst user)) name) (IEq (Scn user) password)

getUserId users username password =
    Fold users (SumL (Lit (U ()))) (\_ candidate acc ->
        If (testUser candidate username password)
            (SumR (Scn (Fst candidate)))
            (Skip (Skip (SumL (Lit (U ())))))
    )

foo = getUserId hashedUsers (Lit user1Name) (hash (Lit user1Pass))