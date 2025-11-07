from enum import Enum

class SAM2Model(Enum):
    TINY = ("./checkpoints/sam2.1_hiera_tiny.pt", "configs/sam2.1/sam2.1_hiera_t.yaml")
    SMALL = ("./checkpoints/sam2.1_hiera_small.pt", "configs/sam2.1/sam2.1_hiera_s.yaml")
    BASE_PLUS = ("./checkpoints/sam2.1_hiera_base_plus.pt", "configs/sam2.1/sam2.1_hiera_b+.yaml")
    LARGE = ("./checkpoints/sam2.1_hiera_large.pt", "configs/sam2.1/sam2.1_hiera_l.yaml")
    
    def __init__(self, checkpoint_path, config_path):
        self.checkpoint_path = checkpoint_path
        self.config_path = config_path

