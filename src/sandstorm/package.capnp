# Sandstorm - Personal Cloud Sandbox
# Copyright (c) 2014, Kenton Varda <temporal@gmail.com>
# All rights reserved.
#
# This file is part of the Sandstorm API, which is licensed as follows.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

@0xdf9bc20172856a3a;
# This file contains schemas relevant to the Sandstorm package format.  See also the `spk` tool.

$import "/capnp/c++.capnp".namespace("sandstorm::spk");

using Util = import "util.capnp";
using Grain = import "grain.capnp";

struct KeyFile {
  # A public/private key pair, as generated by libsodium's crypto_sign_keypair.
  #
  # This format is not actually part of the .spk package, but is used to store keys for later
  # signing of .spk's.
  #
  # TODO(someday):  Integrate with desktop environment's keychain for more secure storage.

  publicKey @0 :Data;
  privateKey @1 :Data;
}

struct Header {
  # A message that is attached to the beginning of a Sandstorm package.  Thus, a package file is
  # a PackageHeader followed by a zip file.  (The zip format has the interesting property that its
  # index is written at the end of the file, and thus standard unzipping tools will be able to
  # unzip a Sandstorm package without removing the header.)

  publicKey @0 :Data;
  # A libsodium crypto_sign public key.
  #
  # The application's ID number is the 128-bit prefix of the sha-256 hash of `publicKey`.  Thus,
  # different packages with the same `publicKey` are considered to be different versions of the
  # same application, and you must generate a different key for every application.

  signature @1 :Data;
  # libsodium crypto_sign signature of the crypto_hash of the zip file part of the package
  # (i.e. the package file minus the header).
}

struct Manifest {
  # This manifest file defines an application.  The file `sandstorm-manifest` at the root of the
  # application's `.spk` package contains a serialized (binary) instance of `Manifest`.

  appVersion @4 :UInt32;
  # Among app packages with the same app ID (i.e. the same `publicKey`), `version` is used to
  # decide which packages represent newer vs. older versions of the app.  The sole purpose of this
  # number is to decide whether one package is newer than another; it is not normally displayed to
  # the user.  This number need not have anything to do with the "marketing version" of your app.

  minUpgradableAppVersion @5 :UInt32;
  # The minimum version of the app which can be safely replaced by this app package without data
  # loss.  This might be non-zero if the app's data store format changed drastically in the past
  # and the app is no longer able to read the old format.

  minApiVersion @0 :UInt32;
  maxApiVersion @1 :UInt32;
  # Min and max API versions against which this app is known to work.  `minApiVersion` primarily
  # exists to warn the user if their instance is too old.  If the sandstorm instance is newer than
  # `maxApiVersion`, it may engage backwards-compatibility hacks and hide features introduced in
  # newer versions.

  struct Command {
    # Description of a command to execute.
    #
    # Note that commands specified this way are NOT interpreted by a shell.  If you want shell
    # expansion, you must include a shell binary in your app and invoke it to interpret the
    # command.

    executablePath @0 :Text;  # Executable filename, within the .spk package.
    args @1 :List(Text);      # Argument list, not including executable name.

    environ @2 :List(Util.KeyValue);
    # Environment variables to set.  The environment will be completely empty other than what you
    # define here.
  }

  struct Action {
    input :union {
      none @0 :Void;
      # This action creates a new grain with no input.  On startup, the grain will export a `UiView`
      # as its default capability.

      capability @1 :Grain.PowerboxQuery;
      # This action creates a new grain from a capability.  When a capability matching the query
      # is offered to the user (e.g. by another application calling SessionContext.offer()), this
      # action will be listed as one of the things the user can do with it.
      #
      # On startup, the grain will export a `PowerboxAction` as its default capability.
    }

    command @2 :Command;
    # Command to execute (in a newly-allocated grain) to run this action.

    title @3 :Util.LocalizedText;
    # Title of this action, to display in the action selector.

    description @4 :Util.LocalizedText;
    # Description of this action, suitable for help text.
  }

  actions @2 :List(Action);
  # Actions which this grain offers.

  continueCommand @3 :Command;
  # Command to run to restart an already-created grain.
}