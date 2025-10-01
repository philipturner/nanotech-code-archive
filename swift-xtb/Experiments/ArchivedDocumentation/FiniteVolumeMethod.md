# Finite Volume Method

First update: Early on, it seemed that finite difference operators would need to reach across multiple resolution levels. That may not be necessary based on the most recent plans. These equations are kept around as an archive, for reference.

Second update: The issue that spawned this article, is a quite fundamental one for my approach. I need to use the Finite Volume Method for DFT, which hasn't been done before.

## Asymmetric Finite Differencing

Variable-resolution orbitals require asymmetric finite differencing. Custom finite difference coefficients were derived for the boundaries between multigrid levels.

<div align="center">

### Symmetric Second-Order

$h^2 f_i'' + \frac{h^4}{12} f_i'''' = f_{i-1} - 2f_i + f_{i+1}$

### Symmetric Fourth-Order

$h^2 f_i'' = \frac{4}{3}(f_{i-1} - 2f_i + f_{i+1}) - \frac{1}{12}(f_{i-2} - 2f_i + f_{i+2})$

### Asymmetric First-Order

$c_- = \frac{1}{h_-}$

$c_+ = \frac{1}{h_+}$

$\frac{h_- + h_+}{2}f_i'' + O(h^2)f_i''' + O(h^3)f_i'''' = c_-f_{i-1} + c_+f_{i+1} - (c_- + c_+)f_i$

### Asymmetric Second-Order

$c_- = \frac{1}{h_-}$

$c_1 = \frac{4h_+^2 - h_-^2}{3h_+^3}$

$c_2 = \frac{h_-^2 - h_+^2}{6h_+^3}$

$(\frac{h_-}{2} + \frac{h_-^2 + 2h_+^2}{6h_+})f_i'' + O(h^3)f_i'''' = c_-f_{i-1} + c_1f_{i+1} + c_2f_{i+2} - (c_- + c_1 + c_2)f_i$

$O(h^3) = \frac{1}{12}(\frac{h_-^3}{2} + \frac{ h_+^2 (7h_-^2 - 4h_+^2) }{6h_+})$

### Doubly Asymmetric Second-Order

$c_- = \frac{1}{h_-}$

$c_1 = \frac{(h_1 + h_2)^2 - h_-^2}{h_1 (2h_1h_2 + h_2^2)}$

$c_2 = \frac{h_-^2 - h_1^2}{(h_1 + h_2)(2h_1h_2 + h_2^2)}$

$(\frac{h_-}{2} + \frac{h_-^2 + h_1^2 + h_1h_2}{4h_1 + 2h_2})f_i'' + O(h^3)f_i'''' = c_-f_{i-1} + c_1f_{i+1} + c_2f_{i+2} - (c_- + c_1 + c_2)f_i$

$O(h^3) = \frac{1}{12}(\frac{h_-^3}{2} + \frac{h_-^2 (3h_1^2 + 3h_1h_2 + h_2^2) - h_1^2 (h_1 + h_2)^2 }{4h_1 + 2h_2})$

</div>

## Finite Volume Method

This seems like the optimal algorithm: https://www.sciencedirect.com/science/article/pii/S0021999105001129

> A fourth-order accurate local refinement method for Poisson’s equation
> 
> We present a block-structured local refinement method for computing solutions to Poisson’s equation in two and three dimensions. It is based on a conservative, finite-volume formulation of the classical Mehrstellen methods. This is combined with finite volume local refinement discretizations to obtain a method that is fourth-order accurate in solution error, and with easily verifiable solvability conditions for Neumann and periodic boundary conditions.
