# == Class: threedtopng::deploy
#
# Deploy 3d2png via scap
#
# === Parameters
# [*manage_user*]
#   boolean - should scap add mwdeploy user
class threedtopng::deploy (
    $manage_user = false,
) {
    require_package('nodejs', 'nodejs-legacy', 'xvfb', 'xauth', 'libgl1-mesa-dri')

    # When installed alongside a mediawiki imagescaler there is no need to add
    # the mwdeploy user and group; however, that is not the case on thumbor
    # machines.
    scap::target { '3d2png/deploy':
        deploy_user => 'mwdeploy',
        manage_user =>  $manage_user,
    }
}
