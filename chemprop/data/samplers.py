from itertools import chain
from typing import Iterator, Optional, Iterable

import numpy as np
from torch.utils.data import Sampler


class SeededSampler(Sampler):
    """A :class`SeededSampler` is a class for iterating through a dataset in a randomly seeded
    fashion"""

    def __init__(self, N: int, seed: int):
        if seed is None:
            raise ValueError("arg 'seed' was `None`! A SeededSampler must be seeded!")

        self.idxs = np.arange(N)
        self.rg = np.random.default_rng(seed)

    def __iter__(self) -> Iterator[int]:
        """an iterator over indices to sample."""
        self.rg.shuffle(self.idxs)

        return iter(self.idxs)

    def __len__(self) -> int:
        """the number of indices that will be sampled."""
        return len(self.idxs)


class ClassBalanceSampler(Sampler):
    """A :class:`ClassBalanceSampler` samples data from a :class:`MolGraphDataset` such that
    positive and negative classes are equally sampled

    Parameters
    ----------
    dataset : MolGraphDataset
        the dataset from which to sample
    seed : int
        the random seed to use for shuffling (only used when `shuffle` is `True`)
    shuffle : bool, default=False
        whether to shuffle the data during sampling
    """

    def __init__(self, Y: np.ndarray, seed: Optional[int] = None, shuffle: bool = False):
        self.shuffle = shuffle
        self.rg = np.random.default_rng(seed)

        idxs = np.arange(len(Y))
        actives = Y.any(1)

        self.pos_idxs = idxs[actives]
        self.neg_idxs = idxs[~actives]

        self.length = 2 * min(len(self.pos_idxs), len(self.neg_idxs))

    def __iter__(self) -> Iterator[int]:
        """an iterator over indices to sample."""
        if self.shuffle:
            self.rg.shuffle(self.pos_idxs)
            self.rg.shuffle(self.neg_idxs)

        return chain(*zip(self.pos_idxs, self.neg_idxs))

    def __len__(self) -> int:
        """the number of indices that will be sampled."""
        return self.length


class DeltaSampler(Sampler):
    """
    Pair datapoints during training.
    """

    def __init__(self, N: int, seed: Optional[int] = None, shuffle: bool = False):
        self.N = N
        self.n_pairs = N**2
        self.idxs = np.arange(self.n_pairs)
        self.shuffle = shuffle
        if self.shuffle:
            self.rg = np.random.default_rng(seed)

    def __iter__(self) -> Iterator[int]:
        """an iterator over indices to sample."""
        if self.shuffle:
            self.rg.shuffle(self.idxs)
        for i in self.idxs:
            yield i//self.N
            yield i%self.N

    def __len__(self) -> int:
        # Needs to be set to ensure all data runs through the model at each epoch:
        return self.n_pairs*2


class PrepairedDeltaSampler(Sampler):
    """
    Choose pairs of data points from predefined list of possible pairs.
    """

    def __init__(self, pairs: Iterable[Iterable], seed: Optional[int] = None, shuffle: bool = False):
        self.pairs = pairs
        self.shuffle = shuffle
        if self.shuffle:
            self.rg = np.random.default_rng(seed)

    def __iter__(self) -> Iterator[int]:
        """an iterator over indices to sample."""
        if self.shuffle:
            self.rg.shuffle(self.pairs)
        for i, p in enumerate(self.pairs):
            yield p[0]
            yield p[1]

    def __len__(self) -> int:
        # Needs to be set to ensure all data runs through the model at each epoch:
        return len(self.pairs)*2
