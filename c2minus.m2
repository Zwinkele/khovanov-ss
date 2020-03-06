needs "braid.m2";
needs "differential.m2";
needs "functions.m2";
needsPackage "Matroids";

-- generate the N ideal
N = method();
N(BraidRes) := (br) -> (
    brMinus := copyRes(br);
    u1Edge := brMinus.edges#(br.r_0);
    removeBrEdge(brMinus, u1Edge);
    
    -- generated by vertices
    N1 := fold((acc, v) -> acc + vertexIdeal(br, v), ideal(0), keys(brMinus.adjacent));
  
    -- generated by cycles of length 3+
    N3 := fold((acc, x) -> acc + vertexCycleIdeal(br, x) + vertexCycleIdeal(br, reverse(x)),
	ideal(0), getCycles((ugraph(brMinus))#0));
    
    return N1 + N3;
);

-- outputs a new hash table with values as keys and vice versa
-- is this used anywhere?
invertTable = method();
invertTable(MutableHashTable) := (ht) -> (
    out := new MutableHashTable;
    htkeys := keys(ht);
    
    for i from 0 to #htkeys-1 do (
	out#(ht#(htkeys#i)) = htkeys#i;
    );

    return out;
);

-- returns whether or not the edge meets the vertex
-- null edges are OK
edgeMeetsVertex = method();
edgeMeetsVertex(Edge, Vertex) := (e, v) -> (
    return e.s == v or e.t == v;
);
edgeMeetsVertex(Nothing, Vertex) := (e, v) -> (
    return false;
);

-- the subideal of N generated by vertices
vertexIdeal = method();
vertexIdeal(BraidRes, Vertex) := (br, v) -> (
    vNeighbors := br.adjacent#v;
    inEdges := {vNeighbors#0, vNeighbors#1};
    outEdges := {vNeighbors#2, vNeighbors#3};
    
    return ideal(fold((acc, e) -> acc * if isNull(e) then 1 else e.var, 1, inEdges) - 
	fold((acc, e) -> acc * if isNull(e) then 1 else e.var, 1, outEdges));
);

-- generate the ideal corresponding to a vertex cycle
-- *of length 3 or more*
-- takes the outside path for clockwise cycles
vertexCycleIdeal = method();
vertexCycleIdeal(BraidRes, List) := (br, cycle) -> (
    inProd := 1;
    outProd := 1;
        
    -- convert the cycle from indices to actual Vertex objects
    indexToVertex := invertTable((ugraph(br))#1);
    vCycle := apply(drop(cycle,-1), a -> indexToVertex#a);
    -- while the first and second vertices of the cycle are connected by multiple edges (not u1)
    while number(br.adjacent#(vCycle#0), e -> (not e.var == br.r_0) and edgeMeetsVertex(e, vCycle#1)) > 1 do (
	-- rotate the cycle
	vCycle = rotate(1, vCycle);
    );

    vCycle = append(append(vCycle, vCycle#0), vCycle#1);
    
    -- now we know that there is only one edge from the first vertex to the second one
    x := vCycle#0;
    y := vCycle#1;
    z := vCycle#2;
    eIndex:= position(br.adjacent#(x), e -> (not e.var == br.r_0) and edgeMeetsVertex(e, y));
    -- the unique edge x -- y
    e := (br.adjacent#(x))#eIndex;
    while #vCycle >= 3 do (
	x = vCycle#0;
	y = vCycle#1;
	z = vCycle#2;
	
	yNeighbors := br.adjacent#(y);
    	inPos := position(yNeighbors, e' -> not isNull(e') and e' == e);
	outPos := (inPos + 1) % 4;
        while (not isNull(yNeighbors#outPos) and (yNeighbors#outPos).var == br.r_0)
	or not edgeMeetsVertex(yNeighbors#outPos, z) do (
	    if not isNull(yNeighbors#outPos) then (
	    	if outPos == 0 or outPos == 1 then (
		    outProd = outProd * (yNeighbors#outPos).var;
	    	) else (
		    inProd = inProd * (yNeighbors#outPos).var;
	    	);
	    );
	    outPos = (outPos + 1) % 4;
	);
        
	e = yNeighbors#outPos;
	vCycle = drop(vCycle, 1);
    );

    return ideal(inProd - outProd);
);

-- the degree of the given vertex
vDegree = method();
vDegree(BraidRes, Vertex) := (br, v) -> number(br.adjacent#v, e -> not isNull(e));

-- the L ideal
L = method();
L(BraidRes, Vertex) := (br, v) -> (
    ws := br.adjacent#v;
    return (ws#0).var + (ws#1).var - (ws#2).var - (ws#3).var;
);

-- the L+ ideal
LPlus = method();
LPlus(BraidRes, Vertex) := (br, v) -> (
    ws := br.adjacent#v;
    return (ws#0).var + (ws#1).var + (ws#2).var + (ws#3).var;
);

-- generate the L_I ideal
LI = method();
LI(BraidRes) := (br) -> (
    out := 0*ideal(br.r_0);
        
    vertices := keys(br.adjacent);
    for i from 0 to #vertices-1 do (
	v := vertices#i;
	if v.row >= 0 and vDegree(br, v) == 4 then (
	    out = out + ideal(L(br, v));
	);
    );

    return out;
);

-- the whole LDPlus chain complex
LDPlus = method();
LDPlus(BraidRes) := DifferentialGradedModule =>
(br) -> (
    vs := keys(br.adjacent);
    out := withZeroDifferential(br.r);
    for i from 0 to #vs-1 do (
	if (vs#i).row < 0 then (
	    out = out ** differentialGradedModule(br.r^2, map(br.r^2, br.r^2,
		    {(0,1) => LPlus(br, vs#i), (1,0) => L(br, vs#i)}), {0, (ZZ/2)_0},
	    	squaresToZero => false);
	);
    );
    return out;
);

-- a Gray code
grayCode = method();
grayCode(ZZ) := ZZ => (n) -> xor(n, n//2);

-- input is two numbers which differ at a single binary bit
-- output is which position that difference is at
changingBit = method();
changingBit(ZZ,ZZ) := ZZ => (a,b) -> size2(xor(a,b))-1;

-- logical XOR
-- why is this not built in to Macaulay2
XOR = method();
XOR(Boolean, Boolean) := Boolean => (a,b) -> if a then not b else b;

-- the complex with quotient modules as vertices and edge maps (d_1s) as edges
crossingComplex = method();
crossingComplex(Braid, BraidRes) :=
(b, sing) -> (
    br := copyRes(sing);
    -- what binary word is represented by the fully-singular resolution
    start := sum(for i from 0 to #b.word-1 list (if b.word#i < 0 then 2^i else 0));
    Ms := new MutableList;
    Ms#start = (br.r^1)/(N(br) + LI(br) + ideal(br.r_0));
    -- traverse the cube starting at the fully-singular resolution    
    for i from 1 to 2^(#b.word)-1 do (
	crossing := changingBit(xor(grayCode(i-1), start), xor(grayCode(i), start));
	if XOR(xor(grayCode(i-1), start) & 2^crossing == 0, b.word#crossing < 0) then (
	    splitCrossing(br, crossing);
	) else (
	    joinCrossing(br, crossing);
	);
    
    	Ms#(xor(grayCode(i), start)) = (br.r^1)/(N(br) + LI(br) + ideal(br.r_0));
    );
    
    M := fold((acc, A) -> acc ++ A, toList(Ms));
    -- steal the edge maps (+ sign assignment) and gradings from another complex
    ec := edgeComplex(b, sing);
    return differentialGradedModule(M, map(M, M, ec.d), ec.g, squaresToZero => false);
);

-- like crossingComplex, but without the quotient modules at each vertex
edgeComplex = method();
edgeComplex(Braid, BraidRes) := (b, br) -> (
    out := withZeroDifferential(br.r);
    for i from 0 to #b.word-1 do (
	c := if b.word#i > 0 then 1 else (
	    adjacentEdges := br.adjacent#(vertex(i,0));
	    (adjacentEdges#1).var - (adjacentEdges#3).var
	);
	edge := differentialGradedModule((br.r)^2,
	    map((br.r)^2, (br.r)^2, {(1,0) => c}), {0,1}, squaresToZero => false);
	out = edge ** out;
    );
    return out;
);

C2Minus = method();
C2Minus(Braid) := (b) -> (
    sing := singularResolution(b);
    A := crossingComplex(b, sing);
    B := LDPlus(sing);
    return tensor'(A,B);
);

-- test it out
b = braid(1, {1,-1});
C' = C2Minus(b);

C = toFiltration(C'.m, C'.g)
del = C'.d

FFunction = p -> trim C#(min(max(p,0),#C-1))
etaFunction = p -> inducedMap(trim(F(p)/F(p+1)), F(p))
AFunction = (r,p) -> trim(kernel inducedMap(trim(F(p)/F(p+r)), F(p), del))
ZFunction = (r,p) -> trim(image inducedMap(, A(r,p), eta(p)))
BFunction = (r,p) -> trim(image inducedMap(, image inducedMap(, A(r-1,p-r+1), del), eta(p)))
EFunction = (r,p) -> trim(Z(r,p)/B(r,p))
EPrimeFunction = (r,p) -> trim(A(r,p)/(image(inducedMap(A(r,p), A(r-1,p-r+1), del)) + A(r-1,p+1)))
EPrimeToEFunction = (r,p) -> inducedMap(E(r,p),E'(r,p))
dFunction = (r,p) -> E'toE(r,p+r) * inducedMap(E'(r,p+r), E'(r,p), del) * inverse(E'toE(r,p))
HFunction = (r,p) -> trim(kernel(d(r,p)) / image(d(r,p-r)))

functionCache = new MutableHashTable
cached = c -> (f -> (if not c#?f then c#f = new MutableHashTable; (i -> (if not c#f#?i then c#f#i = f(i); c#f#i))))

F = (cached(functionCache))(FFunction)
eta = (cached(functionCache))(etaFunction)
A = (cached(functionCache))(AFunction)
Z = (cached(functionCache))(ZFunction)
B = (cached(functionCache))(BFunction)
E = (cached(functionCache))(EFunction)
E' = (cached(functionCache))(EPrimeFunction)
E'toE = (cached(functionCache))(EPrimeToEFunction)
d = (cached(functionCache))(dFunction)
H = (cached(functionCache))(HFunction)