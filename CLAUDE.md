
# Hardened Stocastic Computing Block for FPGA Fabric


The goal of this project is to explore the possible type's of Stocastic 

Computing paradigms and determine the feasibility of the taping out. The most

important thing we can go for is power savings for specific tasks, we are targetting stocastic modeling, image processing, and AI inference, however I am open to any other target that my FPGA might be good at solving competitively. 

# Tools 

- FABulous FPGA 

- Librelane

- And associated tools with running both of these 


# Useful directories
- `~/wiki/fpga` and `~/wiki/fpga_tapeout/` hold relevant previous work and experiments

however they do paint a certain archteicture to be implemented, but I have stepped back and decided I need to experiment and simulation before continuing

-`~/Repos/` has OpenFPGA, FABulous, openlane and librelane experiments
we did


# Directory structure
.
├── CLAUDE.md
├── FABulous_work
├── Librelane_work
└── Stocastic_Blocks

- CLAUDE.md: Initial Instruction file
- FABulous_work: Fabric definition and generation
- Librelane_work: ASIC creation
- Stocastic_Blocks: Supporting files for stocastic computing unit creation such as sims and rtl
- HANDOFF.md: running log to be read before the start of the session and to be filled out at the end of the session. Tells about project state and changes made to increase tracability of project. 
