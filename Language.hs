{-# LANGUAGE DataKinds #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}


module Language where

-- Type level natural
data Nat = Z | S Nat

-- Type level addition
type family Add (n :: Nat) (m :: Nat) :: Nat
type instance Add Z      m = m
type instance Add (S m)  n = S (Add m n)

-- Type level Multiplication
type family Mult (n :: Nat) (m :: Nat) :: Nat
type instance Mult Z     m = Z
type instance Mult (S m) n = (Add n (Mult m n))

type family Max (n :: Nat) (m :: Nat) :: Nat
type instance Max Z Z     = Z
type instance Max Z (S n) = S n
type instance Max (S n) Z = S n
type instance Max (S n) (S m) = S (Max n m)

-- List type, Size is the only thing we leak
infixr 4 :::
data List a (size :: Nat) where
    Nill :: List a Z
    (:::) :: a -> List a m -> List a (S m)

data SumType a b = InL a | InR b

data TypePack a where
    B :: Bool     -> TypePack Bool
    L :: List a s -> TypePack (List a s)
    I :: Int      -> TypePack Int
    U :: () -> TypePack ()
    P :: a -> b  -> TypePack (a, b)
    E :: SumType a b  -> TypePack (SumType a b)

data BoolT = FalseT | TrueT


-- Define the lagnuage
data CoreLang t (s :: Nat) where
    -- Literals
    Lit   :: TypePack a -> CoreLang (TypePack a) Z

    -- Skip
    Skip :: CoreLang (TypePack a) n -> CoreLang (TypePack a) (S n)

    -- Booleans
    And  :: CoreLang (TypePack Bool) m -> CoreLang (TypePack Bool) n -> CoreLang (TypePack Bool) (S (Add m n))
    Or   :: CoreLang (TypePack Bool) m -> CoreLang (TypePack Bool) n -> CoreLang (TypePack Bool) (S (Add m n))
    Not  :: CoreLang (TypePack Bool) m -> CoreLang (TypePack Bool) (S m)

    -- Pairs
    Fst  :: CoreLang (TypePack (TypePack a, TypePack b)) n -> CoreLang (TypePack a) (S n)
    Scn  :: CoreLang (TypePack (TypePack a, TypePack b)) n -> CoreLang (TypePack b) (S n)
    Pair :: CoreLang (TypePack a) n -> CoreLang (TypePack b) m -> CoreLang (TypePack (TypePack a, TypePack b)) (S (Add n m))

    SumL  :: CoreLang (TypePack a) n -> CoreLang (TypePack (SumType (TypePack a) (TypePack b))) (S n)
    SumR  :: CoreLang (TypePack b) n -> CoreLang (TypePack (SumType (TypePack a) (TypePack b))) (S n)
    Case  :: CoreLang (TypePack (SumType (TypePack a) (TypePack b))) n
          -> (CoreLang (TypePack a) Z -> CoreLang (TypePack c) m)
          -> (CoreLang (TypePack b) Z -> CoreLang (TypePack c) m)
          -> CoreLang (TypePack c) (S (Add n m))

    -- Integer
    Plus  :: CoreLang (TypePack Int) m -> CoreLang (TypePack Int) n -> CoreLang (TypePack Int)  (S (Add m n))
    Minus :: CoreLang (TypePack Int) m -> CoreLang (TypePack Int) n -> CoreLang (TypePack Int)  (S (Add m n))
    Time  :: CoreLang (TypePack Int) m -> CoreLang (TypePack Int) n -> CoreLang (TypePack Int)  (S (Add m n))
    Div   :: CoreLang (TypePack Int) m -> CoreLang (TypePack Int) n -> CoreLang (TypePack Int)  (S (Add m n))
    IEq   :: CoreLang (TypePack Int) m -> CoreLang (TypePack Int) n -> CoreLang (TypePack Bool) (S (Add m n))

    -- List operations
    Map  :: CoreLang (TypePack (List (TypePack a) s)) n
         -> (CoreLang (TypePack Int) Z -> CoreLang (TypePack a) Z -> CoreLang (TypePack b) fTime)
         -> CoreLang (TypePack (List (TypePack b) s)) (Add n (Mult fTime s))

    Fold  :: CoreLang (TypePack (List (TypePack a) s)) n
          -> CoreLang (TypePack b) n0 -- accumulator
          -> (CoreLang (TypePack Int) Z -> CoreLang (TypePack a) Z -> CoreLang (TypePack b) Z -> CoreLang (TypePack b) fTime)
          -> CoreLang (TypePack b) (Add n (Add n0 (Mult fTime s)))

    Length :: CoreLang (TypePack (List (TypePack a) s)) n
           -> CoreLang (TypePack Int) (S n)

    Zip :: CoreLang (TypePack (List (TypePack a) s)) n
        -> CoreLang (TypePack (List (TypePack b) s)) m
        -> CoreLang (TypePack (List (TypePack ((TypePack a), (TypePack b))) s)) (Add n (Add m s))


    -- Misc - actually, the relevant stuff
    -- Conditional
    If   :: CoreLang (TypePack Bool) m1 -> CoreLang (TypePack a) m2 -> CoreLang (TypePack a) m2 -> CoreLang (TypePack a) (S (Add m1 m2))

instance Show a => Show (List a s) where
    show (x ::: xs) = (show x) ++ " ::: " ++ (show xs)
    show (Nill)     = "Nill" 

instance Show a => Show (TypePack a) where
    show (B b) = "(B " ++ show b ++ ")"
    show (I i) = "(I " ++ show i ++ ")"
    show (L l) = "(L " ++ show l ++ ")"

instance Show t => Show (CoreLang t s) where
    show (Lit l) = (show l)
--    show (Fold f i l) = "(Fold f " ++ show i ++ " " ++ show l ++ ")"


--An interpreter
interpret :: CoreLang t m -> t

-- Basic operations
interpret (Lit l)  = l
interpret (Skip a) = interpret a
interpret (Or a b) = let
                        a'@(B a'') = interpret a
                        b'@(B b'') = interpret b
                    in 
                        B (a'' || b'')

interpret (And a b) = let
                        a'@(B a'') = interpret a
                        b'@(B b'') = interpret b
                    in 
                        B (a'' && b'')

interpret (Not a) = let
                        a'@(B a'') = interpret a
                    in
                        B (a'')

interpret (Plus a b) = let
                          a'@(I a'') = interpret a
                          b'@(I b'') = interpret b
                      in
                          I (a'' + b'')

interpret (Minus a b) = let
                          a'@(I a'') = interpret a
                          b'@(I b'') = interpret b
                      in
                          I (a'' - b'')

interpret (Time a b) = let
                          a'@(I a'') = interpret a
                          b'@(I b'') = interpret b
                      in
                          I (a'' * b'')

interpret (Div a b) = let
                          a'@(I a'') = interpret a
                          b'@(I b'') = interpret b
                      in
                          I (div a''  b'')

interpret (IEq a b) = let
                          a'@(I a'') = interpret a
                          b'@(I b'') = interpret b
                      in
                          B (a'' == b'')


-- Sum types
interpret (SumL a) = E (InL (interpret a))
interpret (SumR a) = E (InR (interpret a))

interpret (Case a f g) = case (interpret a) of
                           (E (InL b)) -> interpret (f (Lit b))
                           (E (InR c)) -> interpret (g (Lit c))

-- Product types
interpret (Fst p) = case (interpret p) of
                      (P a b) -> a

interpret (Scn p) = case (interpret p) of
                    (P a b) -> b

interpret (Pair a b) = (P (interpret a) (interpret b))

-- List operations

interpret (Length list) = I (findLength (interpret list))
  where
    findLength :: TypePack (List (TypePack a) s) -> Int
    findLength (L Nill) = 0
    findLength (L (x ::: xs)) = 1 + (findLength (L xs))

interpret (Map list f) = doMap (interpret list) f 0
  where
    doMap :: TypePack (List (TypePack a) s) -> (CoreLang (TypePack Int) Z -> CoreLang (TypePack a) Z -> CoreLang (TypePack b) fTime) -> Int -> TypePack (List (TypePack b) s)
    doMap (L Nill) f count          = (L Nill)
    doMap (L (x ::: xs)) f count    = case (doMap (L xs) f (count + 1)) of
                                           (L e) -> (L ((interpret (f (Lit (I count)) (Lit x))) ::: e))

interpret (Fold list n f) = doFold (interpret list) f (interpret n) 0
  where
    doFold :: TypePack (List (TypePack a) s) -> (CoreLang (TypePack Int) Z -> CoreLang (TypePack a) Z -> CoreLang (TypePack b) Z -> CoreLang (TypePack b) fTime) -> TypePack b -> Int -> (TypePack b)
    doFold (L Nill) f n count          = n
    doFold (L (x ::: xs)) f n count    = doFold (L xs) (f) (interpret (f (Lit (I count)) (Lit x) (Lit n))) (count + 1)

interpret (Zip xs ys) = doZip (interpret xs) (interpret ys)
  where
    doZip :: TypePack (List (TypePack a) s) -> TypePack (List (TypePack b) s) -> TypePack (List (TypePack ((TypePack a), (TypePack b))) s)
    doZip (L Nill) (L Nill) = (L Nill)
    doZip (L (x ::: xs)) (L (y ::: ys)) = case (doZip (L xs) (L ys)) of
                                            (L e) -> L(P x y ::: e)


-- If
interpret (If cond tBranch fBranch) = let 
                                        cond'@(B cond'') = interpret cond
                                        tBranch' = interpret tBranch
                                        fBranch' = interpret fBranch
                                    in
                                        if cond'' then tBranch' else fBranch'


------------- END INTERPRETER -------------



--- USER/PASSWORD EXAMPLE ---
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





mapTest list = (Map list (\_ b -> (And
    (And (Lit (B True)) b)) (Lit (B True)) ))

-- Does not typecheck!!!
--noTypeCheckTest = If 
--                (Lit (B True)) 
--                (Lit (B False)) 
--                (Or (Lit (B True)) (Lit (B False)))

-- Does type check
doesTypeCheckTest = If 
                (Lit (B True)) 
                (And (Lit (B True)) (Lit (B False)))
                (Or (Lit (B True)) (Lit (B False)))

{- Some Applications -}

-- Secure login, User

-- ordinary Haskell
--checkUser us ul = foldl (||) False (map (==us) ul)

--userList = LList (LInt 133 ::: LInt 3434 ::: LInt 23234 ::: LInt 3434 ::: Nill)
--userCheckTrue  = (LInt 133)
--userCheckFalse = (LInt 323)


{-
This first example generates a program which can check if a user exists in a list
-}
-- Note that we can force literals in the type
--checkUser :: CoreLang Int Z 
--    -> CoreLang (List (CoreLang Int Z) s) (S (Add Z Z)) 
--    -> CoreLang Bool (Add (Mult s (S Z)) Z)

--elementEquals x xs = (Map xs (\y -> (IEq y x)))
{-
doOr :: CoreLang Bool m -> CoreLang Bool n -> CoreLang Bool (S (Add m n))
doOr a b = (Or a b)

false :: CoreLang Bool Z
false = (Lit $ B False)


--foldOr :: CoreLang (List Bool s) s -> CoreLang Bool s
--foldOr xs = (Fold doOr false xs)

--    Fold :: (CoreLang a m1 -> CoreLang a m2 -> CoreLang a (S (Add m1 m2))) -- function, only constant operations time
--        -> CoreLang a n0 -- Neutral element
--        -> CoreLang (List (CoreLang a n1) s) n2 --list to fold over
--        -> CoreLang a (Add (Mult s (S (Add m1 m2))) n0)

-- checkUser user uList         = 
-}
-- Generate expression for execution
--cuExp = checkUser (LInt 133) userList


-- Safe multi threading (relate to the presented paper)

{-

# Problems doing this:

## Fold

* Functions used to fold has to be dependent, so we can statically infer running time

-}