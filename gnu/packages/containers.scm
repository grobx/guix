;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2021 Timmy Douglas <mail@timmydouglas.com>
;;;
;;; This file is part of GNU Guix.
;;;
;;; GNU Guix is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; GNU Guix is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Guix.  If not, see <http://www.gnu.org/licenses/>.

(define-module (gnu packages containers)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system go)
  #:use-module (guix build-system meson)
  #:use-module (guix utils)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages check)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gnupg)
  #:use-module (gnu packages golang)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages python)
  #:use-module (gnu packages networking)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages selinux)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages virtualization)
  #:use-module (gnu packages web))

(define-public crun
  (let ((commit "8e5757a4e68590326dafe8a8b1b4a584b10a1370"))
    (package
      (name "crun")
      (version "1.3")
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://github.com/containers/crun")
               (commit commit)
               (recursive? #t)))
         (sha256
          (base32 "01yiss2d57kwlxb7zlqzjwlg9fyaf19yjngd1mw9n4hxls3dfj3k"))
         (file-name (git-file-name name version))))
      (build-system gnu-build-system)
      (arguments
       `(#:configure-flags '("--disable-systemd")
         #:tests? #f ; XXX: needs /sys/fs/cgroup mounted
         #:phases
         (modify-phases %standard-phases
           (add-after 'unpack 'do-not-depend-on-git
             (lambda _
               (substitute* "autogen.sh"
                 (("^git submodule update.*")
                  ""))
               (with-output-to-file "git-version.h"
                 (lambda ()
                   (display (string-append
                             "/* autogenerated.  */\n#ifndef GIT_VERSION\n# define GIT_VERSION \""
                             ,commit
                             "\"\n#endif\n"))))))
           (add-after 'unpack 'fix-tests
             (lambda _
               (substitute* (find-files "tests" "\\.(c|py)")
                 (("/bin/true") (which "true"))
                 (("/bin/false") (which "false"))
                 ; relies on sd_notify which requires systemd?
                 (("\"sd-notify\" : test_sd_notify,") "")
                 (("\"sd-notify-file\" : test_sd_notify_file,") "")))))))
      (inputs
       (list libcap
             libseccomp
             libyajl))
      (native-inputs
       (list automake
             autoconf
             git
             libtool
             pkg-config
             python-3))
      (home-page "https://github.com/containers/crun")
      (synopsis "Open Container Initiative (OCI) Container runtime")
      (description
       "crun is a fast and low-memory footprint Open Container Initiative (OCI)
Container Runtime fully written in C.")
      (license license:gpl2+))))

(define-public conmon
  (package
    (name "conmon")
    (version "2.0.30")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/containers/conmon")
             (commit (string-append "v" version))))
       (sha256
        (base32 "1sxpbm01g4xak4kqwvk45gmzr6n9bjzlfp1j85wyz8rj2hg2x4rm"))
       (file-name (git-file-name name version))))
    (build-system gnu-build-system)
    (arguments
     `(#:make-flags (list ,(string-append "CC=" (cc-for-target))
                          (string-append "PREFIX=" %output))
       ;; XXX: uses `go get` to download 50 packages, runs a ginkgo test suite
       ;; then tries to download busybox and use a systemd logging library
       ;; see also https://github.com/containers/conmon/blob/main/nix/derivation.nix
       #:tests? #f
       #:test-target "test"
       #:phases (modify-phases %standard-phases
                  (delete 'configure)
                  (add-after 'unpack 'set-env
                    (lambda* (#:key inputs #:allow-other-keys)
                      ;; when running go, things fail because
                      ;; HOME=/homeless-shelter.
                      (setenv "HOME" "/tmp"))))))
    (inputs
     (list crun
           glib
           libseccomp))
    (native-inputs
     (list git
           go
           pkg-config))
    (home-page "https://github.com/containers/conmon")
    (synopsis "Monitoring tool for Open Container Initiative (OCI) runtime")
    (description
     "Conmon is a monitoring program and communication tool between a container
manager (like Podman or CRI-O) and an Open Container Initiative (OCI)
runtime (like runc or crun) for a single container.")
    (license license:asl2.0)))

(define-public libslirp
  (package
    (name "libslirp")
    (version "4.6.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://gitlab.freedesktop.org/slirp/libslirp")
             (commit (string-append "v" version))))
       (sha256
        (base32 "1b4cn51xvzbrxd63g6w1033prvbxfxsnsn1l0fa5i311xv28vkh0"))
       (file-name (git-file-name name version))))
    (build-system meson-build-system)
    (inputs
     (list glib))
    (native-inputs
     (list pkg-config))
    (home-page "https://gitlab.freedesktop.org/slirp/libslirp")
    (synopsis "User-mode networking library")
    (description
     "libslirp is a user-mode networking library used by virtual machines,
containers or various tools.")
    (license license:bsd-3)))

(define-public slirp4netns
  (package
    (name "slirp4netns")
    (version "1.1.12")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/rootless-containers/slirp4netns")
             (commit (string-append "v" version))))
       (sha256
        (base32 "03llv4dlf7qqxwz4zdyk926g4bigfj2gb50glm70ciflpvzs8081"))
       (file-name (git-file-name name version))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f ; XXX: open("/dev/net/tun"): No such file or directory
       #:phases (modify-phases %standard-phases
                  (add-after 'unpack 'fix-hardcoded-paths
                    (lambda _
                      (substitute* (find-files "tests" "\\.sh")
                        (("ping") "/run/setuid-programs/ping")))))))
    (inputs
     (list glib
           libcap
           libseccomp
           libslirp))
    (native-inputs
     (list automake
           autoconf
           iproute ; iproute, jq, nmap (ncat) and util-linux are for tests
           jq
           nmap
           pkg-config
           util-linux))
    (home-page "https://github.com/rootless-containers/slirp4netns")
    (synopsis "User-mode networking for unprivileged network namespaces")
    (description
     "slirp4netns provides user-mode networking (\"slirp\") for unprivileged
network namespaces.")
    (license license:gpl2+)))

(define-public cni-plugins
  (package
    (name "cni-plugins")
    (version "1.0.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/containernetworking/plugins")
             (commit (string-append "v" version))))
       (sha256
        (base32 "1j91in0mg4nblpdccyq63ncbnn2pc2zzjp1fh3jy0bsndllgv0nc"))
       (file-name (git-file-name name version))))
    (build-system go-build-system)
    (arguments
     `(#:unpack-path "github.com/containernetworking/plugins"
       #:tests? #f ; XXX: see stat /var/run below
       #:phases (modify-phases %standard-phases
                  (replace 'build
                    (lambda _
                      (with-directory-excursion
                          "src/github.com/containernetworking/plugins"
                        (invoke "./build_linux.sh"))))
                  (replace 'check
                    (lambda* (#:key tests? #:allow-other-keys)
                      ; only pkg/ns tests run without root
                      (when tests?
                        (with-directory-excursion
                            "src/github.com/containernetworking/plugins/pkg/ns"
                          (invoke "stat" "/var/run") ; XXX: test tries to stat this directory
                          (invoke "unshare" "-rmn" "go" "test")))))
                  (add-before 'check 'set-test-environment
                    (lambda _
                      (setenv "XDG_RUNTIME_DIR" "/tmp/cni-rootless")))
                  (replace 'install
                    (lambda* (#:key outputs #:allow-other-keys)
                      (copy-recursively
                       "src/github.com/containernetworking/plugins/bin"
                       (string-append (assoc-ref outputs "out") "/bin")))))))
    (native-inputs
     (list util-linux))
    (home-page "https://github.com/containernetworking/plugins")
    (synopsis "Container Network Interface (CNI) network plugins")
    (description
     "This package provides Container Network Interface (CNI) plugins to
configure network interfaces in Linux containers.")
    (license license:asl2.0)))

;; For podman to work, the user needs to run
;; `sudo mount -t cgroup2 none /sys/fs/cgroup`

(define-public podman
  (package
    (name "podman")
    (version "3.4.4")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/containers/podman")
             (commit (string-append "v" version))))
       (sha256
        (base32 "1q09qsl1wwiiy5njvb97n1j5f5jin4ckmzj5xbdfs28czb2kx3g5"))
       (file-name (git-file-name name version))))

    (build-system gnu-build-system)
    (arguments
     `(#:make-flags (list ,(string-append "CC=" (cc-for-target))
                          (string-append "PREFIX=" %output))
       #:tests? #f ; /sys/fs/cgroup not set up in guix sandbox
       #:test-target "test"
       #:phases (modify-phases %standard-phases
                  (delete 'configure)
                  (add-after 'unpack 'set-env
                    (lambda* (#:key inputs #:allow-other-keys)
                      ;; when running go, things fail because
                      ;; HOME=/homeless-shelter.
                      (setenv "HOME" "/tmp")))
                  (replace 'check
                    (lambda* (#:key tests? #:allow-other-keys)
                      (when tests?
                        ;; (invoke "strace" "-f" "bin/podman" "version")
                        (invoke "make" "localsystem")
                        (invoke "make" "remotesystem"))))
                  (add-after 'unpack 'fix-hardcoded-paths
                    (lambda _
                      (substitute* (find-files "libpod" "\\.go")
                        (("exec.LookPath[(][\"]slirp4netns[\"][)]")
                         (string-append "exec.LookPath(\""
                                        (which "slirp4netns") "\")")))
                      (substitute* "hack/install_catatonit.sh"
                        (("CATATONIT_PATH=\"[^\"]+\"")
                         (string-append "CATATONIT_PATH=" (which "true"))))
                      (substitute* "vendor/github.com/containers/common/pkg/config/config_linux.go"
                        (("/usr/local/libexec/podman")
                         (string-append (assoc-ref %outputs "out") "/bin")))
                      (substitute* "vendor/github.com/containers/common/pkg/config/default.go"
                        (("/usr/libexec/podman/conmon") (which "conmon"))
                        (("/usr/local/libexec/cni")
                         (string-append (assoc-ref %build-inputs "cni-plugins")
                                        "/bin"))
                        (("/usr/bin/crun") (which "crun"))))))))
    (inputs
     (list btrfs-progs
           cni-plugins
           conmon
           crun
           gpgme
           go-github-com-go-md2man
           iptables
           libassuan
           libseccomp
           libselinux
           slirp4netns))
    (native-inputs
     (list bats
           git
           go
           ; strace ; XXX debug
           pkg-config))
    (home-page "https://podman.io")
    (synopsis "Manage containers, images, pods, and their volumes")
    (description
     "Podman (the POD MANager) is a tool for managing containers and images,
volumes mounted into those containers, and pods made from groups of
containers.")
    (license license:asl2.0)))
