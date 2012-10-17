#!/usr/bin/env perl

use strict;
use warnings;

use FindBin '$RealBin';

BEGIN {
    unshift @INC, "$RealBin/lib";
    unshift @INC, "$_/lib" for glob "$RealBin/contrib/*";
}

use File::Basename;

use Plack::Builder;
use Plack::App::Directory;

use SockJS;

my %options = (sockjs_url => '/sockjs.min.js');

my %sessions;

my $handler = sub {
    my ($session) = @_;

    $sessions{"$session"} = $session;

    $session->on(
        'data' => sub {
            my $session = shift;

            foreach my $other (keys %sessions) {
                next if $other eq $session;

                $sessions{$other}->write(@_);
            }
        }
    );
};

my $root = File::Basename::dirname(__FILE__);

builder {
    mount '/draw' => SockJS->new(%options, handler => $handler);

    mount '/' => builder {
        enable "Plack::Middleware::Static",
          path => qr{(?:^/images|\.(?:html|js|css)$)},
          root => "$root/public/";

        sub {
            my $env = shift;

            my $path_info = $env->{PATH_INFO};
            if ($path_info eq '' || $path_info eq '/') {
                return [302, [Location => '/index.html'], []];
            }

            return [404, ['Content-Length' => 0], []];
        };
    };
};
