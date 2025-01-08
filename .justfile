install:
    #!/usr/bin/env bash
    if [ ! -d 'terminil' ]; then
        git clone https://github.com/david-d-h/terminil.git;
        gleam build;
    fi

[working-directory: 'example']
run example: install
    gleam run;
