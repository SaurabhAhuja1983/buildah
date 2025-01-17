#!/usr/bin/env bats

load helpers

# Ensure that any updated/pushed rpm .spec files don't clobber the commit placeholder
@test "rpm REPLACEWITHCOMMITID placeholder exists in .spec file" {
	run grep -q "^%global[ ]\+commit[ ]\+REPLACEWITHCOMMITID$" ${TEST_SOURCES}/../contrib/rpm/buildah.spec
	[ "$status" -eq 0 ]
}

@test "rpm-build CentOS 7" {
        skip_if_no_runtime

        # Build a container to use for building the binaries.
        image=docker.io/library/centos:centos7
        cid=$(buildah from --pull --signature-policy ${TEST_SOURCES}/policy.json $image)
        root=$(buildah mount $cid)
        commit=$(git log --format=%H -n 1)
        shortcommit=$(echo ${commit} | cut -c-7)
        mkdir -p ${root}/rpmbuild/{SOURCES,SPECS}

        # Build the tarball.
        (cd ..; git archive --format tar.gz --prefix=buildah-${commit}/ ${commit}) > ${root}/rpmbuild/SOURCES/buildah-${shortcommit}.tar.gz

        # Update the .spec file with the commit ID.
        sed s:REPLACEWITHCOMMITID:${commit}:g ${TEST_SOURCES}/../contrib/rpm/buildah.spec > ${root}/rpmbuild/SPECS/buildah.spec

        # Install build dependencies and build binary packages.
        buildah run $cid -- yum -y install rpm-build yum-utils
        buildah run $cid -- yum-builddep -y rpmbuild/SPECS/buildah.spec
        buildah run $cid -- rpmbuild --define "_topdir /rpmbuild" -ba /rpmbuild/SPECS/buildah.spec

        # Build a second new container.
        cid2=$(buildah from --pull --signature-policy ${TEST_SOURCES}/policy.json $image)
        root2=$(buildah mount $cid2)

        # Copy the binary packages from the first container to the second one, and build a list of
        # their filenames relative to the root of the second container.
        rpms=
        mkdir -p ${root2}/packages
        for rpm in ${root}/rpmbuild/RPMS/*/*.rpm ; do
                cp $rpm ${root2}/packages/
                rpms="$rpms "/packages/$(basename $rpm)
        done

        # Install the binary packages into the second container.
        buildah run $cid2 -- yum -y install $rpms

        # Run the binary package and compare its self-identified version to the one we tried to build.
        id=$(buildah run $cid2 -- buildah version | awk '/^Git Commit:/ { print $NF }')
        bv=$(buildah run $cid2 -- buildah version | awk '/^Version:/ { print $NF }')
        rv=$(buildah run $cid2 -- rpm -q --queryformat '%{version}' buildah)
        echo "short commit: $shortcommit"
        echo "id: $id"
        echo "buildah version: $bv"
        echo "buildah rpm version: $rv"
        test $shortcommit = $id
        test $bv = ${rv} -o $bv = ${rv}-dev

        # Clean up.
        buildah rm $cid $cid2
}

@test "rpm-build Fedora latest" {
        skip_if_no_runtime

        # Build a container to use for building the binaries.
        image=registry.fedoraproject.org/fedora:latest
        cid=$(buildah from --pull --signature-policy ${TEST_SOURCES}/policy.json $image)
        root=$(buildah mount $cid)
        commit=$(git log --format=%H -n 1)
        shortcommit=$(echo ${commit} | cut -c-7)
        mkdir -p ${root}/rpmbuild/{SOURCES,SPECS}

        # Build the tarball.
        (cd ..; git archive --format tar.gz --prefix=buildah-${commit}/ ${commit}) > ${root}/rpmbuild/SOURCES/buildah-${shortcommit}.tar.gz

        # Update the .spec file with the commit ID.
        sed s:REPLACEWITHCOMMITID:${commit}:g ${TEST_SOURCES}/../contrib/rpm/buildah.spec > ${root}/rpmbuild/SPECS/buildah.spec

        # Install build dependencies and build binary packages.
        buildah run $cid -- dnf -y install 'dnf-command(builddep)' rpm-build
        buildah run $cid -- dnf -y builddep --spec rpmbuild/SPECS/buildah.spec
        buildah run $cid -- rpmbuild --define "_topdir /rpmbuild" -ba /rpmbuild/SPECS/buildah.spec

        # Build a second new container.
        cid2=$(buildah from --pull --signature-policy ${TEST_SOURCES}/policy.json $image)
        root2=$(buildah mount $cid2)

        # Copy the binary packages from the first container to the second one, and build a list of
        # their filenames relative to the root of the second container.
        rpms=
        mkdir -p ${root2}/packages
        for rpm in ${root}/rpmbuild/RPMS/*/*.rpm ; do
                cp $rpm ${root2}/packages/
                rpms="$rpms "/packages/$(basename $rpm)
        done

        # Install the binary packages into the second container.
        buildah run $cid2 -- dnf -y install $rpms

        # Run the binary package and compare its self-identified version to the one we tried to build.
        id=$(buildah run $cid2 -- buildah version | awk '/^Git Commit:/ { print $NF }')
        bv=$(buildah run $cid2 -- buildah version | awk '/^Version:/ { print $NF }')
        rv=$(buildah run $cid2 -- rpm -q --queryformat '%{version}' buildah)
        echo "short commit: $shortcommit"
        echo "id: $id"
        echo "buildah version: $bv"
        echo "buildah rpm version: $rv"
        test $shortcommit = $id
	test $bv = ${rv} -o $bv = ${rv}-dev

        # Clean up.
        buildah rm $cid $cid2
}
