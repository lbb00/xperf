struct powertrain {
    unsigned char electric : 1;
    unsigned char gasoline : 1;
    unsigned char diesel : 1;
    unsigned char plugin : 1;
};

struct powertrain_mask {
    unsigned kind;
};

struct two_flags {
    int is_open;
    int is_ready;
};
