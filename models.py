from enum import Enum


class SAMModel(Enum):
    """SAM 1 model variants with checkpoint paths and model types."""
    VIT_B = ("./checkpoints/sam_vit_b_01ec64.pth", "vit_b")
    VIT_L = ("./checkpoints/sam_vit_l_0b3195.pth", "vit_l")
    VIT_H = ("./checkpoints/sam_vit_h_4b8939.pth", "vit_h")

    def __init__(self, checkpoint_path, model_type):
        self.checkpoint_path = checkpoint_path
        self.model_type = model_type

