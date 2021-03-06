# Filtering functions

```@docs
imfilter
imfilter!
imgradients
extrema_filter
```

# Kernel

```@docs
Kernel.sobel
Kernel.prewitt
Kernel.ando3
Kernel.ando4
Kernel.ando5
Kernel.gaussian
Kernel.DoG
Kernel.LoG
Kernel.Laplacian
```

# KernelFactors

```@docs
KernelFactors.sobel
KernelFactors.prewitt
KernelFactors.ando3
KernelFactors.ando4
KernelFactors.ando5
KernelFactors.gaussian
KernelFactors.IIRGaussian
KernelFactors.TriggsSdika
```

# Kernel utilities

```@docs
centered
kernelfactors
reflect
```

# Boundaries and padding

```@docs
padarray
Pad
Fill
Inner
NA
NoPad
```

# Algorithms

```@docs
Algorithm.FIR
Algorithm.FFT
Algorithm.IIR
Algorithm.Mixed
```

# Internal machinery

```@docs
KernelFactors.ReshapedOneD
```
