# Data files of the skins2 interface

if host_system == 'windows'
    # VLC looks for the skins next to the executable on Windows
    skins2_install_dir = prefix_path / 'skins'
else
    skins2_install_dir = pkgdatadir_path / 'skins2'
endif

install_data(
    'fonts/FreeSans.ttf',
    'fonts/FreeSansBold.ttf',
    'skin.dtd',
    'skin.catalog',
    'winamp2.xml',
    install_dir: skins2_install_dir,
    preserve_path: true)

# Content of the default skin archive, in the order it is stored
default_vlt_files = files(
    'default/subX/about.png',
    'default/subX/eq.png',
    'default/subX/font.otf',
    'default/subX/main.png',
    'default/subX/pl.png',
    'default/subX/playtreeglyphs.png',
    'default/subX/sysbuttons.png',
    'default/subX/vol_anim.png',
    'default/subX/vol_slider.png',
    'default/theme.xml',
)

# Store root as the owner of the files like the autotools build. This is not
# supported by the tar of macOS.
tar = find_program('tar')
if build_machine.system() == 'darwin'
    tar_owner_args = []
else
    tar_owner_args = ['--owner=root', '--group=root']
endif

relative_vlt_files = []
foreach f : default_vlt_files
    relative_vlt_files += fs.relative_to(f, meson.current_source_dir())
endforeach

custom_target(
    input: default_vlt_files,
    output: 'default.vlt',
    command: [tar, 'cvvzf', '@OUTPUT@', '--format=ustar', tar_owner_args,
            '--directory=' + meson.current_source_dir(), relative_vlt_files
    ],
    env: {'GZIP': '--no-name'},
    console: true,
    install: true,
    install_dir: skins2_install_dir)
