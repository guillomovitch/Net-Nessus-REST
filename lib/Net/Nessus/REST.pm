package Net::Nessus::REST;

use warnings;
use strict;

use Carp;
use LWP::UserAgent;
use JSON;
use List::Util qw(first);

our $VERSION = 0.2;

sub new {
    my ($class, %params) = @_;

    my $url   = $params{url} || 'https://localhost:8834/';
    my $agent = LWP::UserAgent->new();

    $agent->timeout($params{timeout})
        if $params{timeout};
    $agent->ssl_opts(%{$params{ssl_opts}})
        if $params{ssl_opts} && ref $params{ssl_opts} eq 'HASH';

    my $self = {
        url   => $url,
        agent => $agent
    };
    bless $self, $class;

    return $self;
}

sub create_session {
    my ($self, %params) = @_;

    my $result = $self->_post("/session", %params);
    $self->{agent}->default_header('X-Cookie' => "token=$result->{token}");
}

sub destroy_session {
    my ($self, %params) = @_;

    $self->{agent}->delete($self->{url} . '/session');
}

sub list_policies {
    my ($self) = @_;

    my $result = $self->_get('/policies');
    return $result->{policies} ? @{$result->{policies}} : ();
}

sub get_policy_id {
    my ($self, %params) = @_;

    croak "missing name parameter" unless $params{name};

    my $policy = first { $_->{name} eq $params{name} } $self->list_policies();
    return unless $policy;

    return $policy->{id};
}

sub create_scan {
    my ($self, %params) = @_;

    croak "missing uuid parameter" unless $params{uuid};
    croak "missing settings parameter" unless $params{settings};

    my $result = $self->_post("/scans", %params);
    return $result->{scan};
}

sub configure_scan {
    my ($self, %params) = @_;

    croak "missing scan_id parameter" unless $params{scan_id};
    croak "missing uuid parameter" unless $params{uuid};
    croak "missing settings parameter" unless $params{settings};

    my $scan_id = delete $params{scan_id};

    my $result = $self->_put("/scans/$scan_id", %params);
    return $result;
}

sub delete_scan {
    my ($self, %params) = @_;

    croak "missing scan_id parameter" unless $params{scan_id};

    my $scan_id = delete $params{scan_id};

    my $result = $self->_delete("/scans/$scan_id");
    return 1;
}

sub delete_scan_history {
    my ($self, %params) = @_;

    croak "missing scan_id parameter" unless $params{scan_id};
    croak "missing history_id parameter" unless $params{history_id};

    my $scan_id = delete $params{scan_id};
    my $history_id = delete $params{history_id};

    my $result = $self->_delete("/scans/$scan_id/history/$history_id");
    return 1;
}

sub list_scans {
    my ($self, %params) = @_;

    my $result = $self->_get('/scans', %params);
    return $result ? @{$result} : ();
}

sub launch_scan {
    my ($self, %params) = @_;

    croak "missing scan_id parameter" unless $params{scan_id};
    my $scan_id = delete $params{scan_id};

    my $result = $self->_post("/scans/$scan_id/launch", %params);
    return $result->{scan_uuid};
}

sub get_scan_details {
    my ($self, %params) = @_;

    croak "missing scan_id parameter" unless $params{scan_id};

    my $scan_id = delete $params{scan_id};

    my $result = $self->_get("/scans/$scan_id", %params);
    return $result;
}

sub set_scan_read_status {
    my ($self, %params) = @_;

    croak "missing scan_id parameter" unless $params{scan_id};
    croak "missing status parameter" unless $params{status};
    croak "invalid status parameter" unless $params{status} eq 'read' or
                                            $params{status} eq 'unread';

    my $scan_id = delete $params{scan_id};

    my $result = $self->_put("/scans/$scan_id/status", %params);
    return 1;
}

sub export_scan {
    my ($self, %params) = @_;

    croak "missing scan_id parameter" unless $params{scan_id};
    croak "missing format parameter" unless $params{format};
    croak "invalid format parameter" unless $params{format} eq 'nessus' or
                                            $params{format} eq 'html'   or
                                            $params{format} eq 'pdf'    or
                                            $params{format} eq 'csv'    or
                                            $params{format} eq 'db';

    my $scan_id = delete $params{scan_id};

    my $result = $self->_post("/scans/$scan_id/export", %params);
    return $result->{file};
}

sub get_scan_export_status {
    my ($self, %params) = @_;

    croak "missing scan_id parameter" unless $params{scan_id};
    croak "missing file_id parameter" unless $params{file_id};

    my $scan_id = delete $params{scan_id};
    my $file_id = delete $params{file_id};

    my $result = $self->_get("/scans/$scan_id/export/$file_id/status");
    return $result->{status};
}

sub download_scan {
    my ($self, %params) = @_;

    croak "missing scan_id parameter" unless $params{scan_id};
    croak "missing file_id parameter" unless $params{file_id};

    my $scan_id = delete $params{scan_id};
    my $file_id = delete $params{file_id};

    my $response = $self->{agent}->get(
        $self->{url} . "/scans/$scan_id/export/$file_id/download",
        ( defined($params{filename}) ? "':content_file' => $params{filename}" : "")
    );

    if ($response->is_success()) {
        if (defined($params{filename})) {
            return 1;
        } else {
            return $response->content;
        }
    } else {
        croak "communication error: " . $response->message()
    }
}

sub get_scan_host_details {
    my ($self, %params) = @_;

    croak "missing scan_id parameter" unless $params{scan_id};
    croak "missing host_id parameter" unless $params{host_id};

    my $scan_id = delete $params{scan_id};
    my $host_id = delete $params{host_id};

    my $result = $self->_get("/scans/$scan_id/hosts/$host_id", %params);
    return $result;
}

sub get_scan_plugin_output {
    my ($self, %params) = @_;

    croak "missing scan_id parameter" unless $params{scan_id};
    croak "missing host_id parameter" unless $params{host_id};
    croak "missing plugin_id parameter" unless $params{plugin_id};

    my $scan_id = delete $params{scan_id};
    my $host_id = delete $params{host_id};
    my $plugin_id = delete $params{plugin_id};

    my $result = $self->_get("/scans/$scan_id/hosts/$host_id/plugins/$plugin_id", %params);
    return $result;
}

sub list_templates {
    my ($self, %params) = @_;

    croak "missing type parameter" unless $params{type};
    croak "invalid type parameter" unless $params{type} eq 'scan' or
                                          $params{type} eq 'policy';

    my $type = delete $params{type};

    my $result = $self->_get("/editor/$type/templates");
    return $result->{templates} ? @{$result->{templates}} : ();
}

sub get_template_id {
    my ($self, %params) = @_;

    croak "missing name parameter" unless $params{name};

    my $template =
        first { $_->{name} eq $params{name} }
        $self->list_templates(type => $params{type});
    return unless $template;

    return $template->{uuid};
}

sub get_scan_id {
    my ($self, %params) = @_;

    croak "missing name parameter" unless $params{name};

    my $scan =
        first { $_->{name} eq $params{name} }
        $self->list_scans();
    return unless $scan;

    return $scan->{id};
}

sub get_scan_status {
    my ($self, %params) = @_;

    croak "missing scan_id parameter" unless $params{scan_id};

    my $details = $self->get_scan_details(scan_id => $params{scan_id});
    return $details->{info}->{status};
}

sub get_scan_history_id {
    my ($self, %params) = @_;

    croak "missing scan_id parameter" unless $params{scan_id};
    croak "missing scan_uuid parameter" unless $params{scan_uuid};

    my $details = $self->get_scan_details(scan_id => $params{scan_id});
    my $history =
        first { $_->{uuid} eq $params{scan_uuid} }
        @{$details->{history}};

    return $history->{history_id};
}

sub list_scanners {
    my ($self) = @_;

    my $result = $self->_get("/scanners");
    return $result ? @{$result} : ();
}

sub list_folders {
    my ($self) = @_;

    my $result = $self->_get("/folders");
    return $result->{folders} ? @{$result->{folders}} : ();
}

sub get_folder_id {
    my ($self, %params) = @_;

    croak "missing name parameter" unless $params{name};

    my $folder = first { $_->{name} eq $params{name} } $self->list_folders();
    return unless $folder;

    return $folder->{id};
}

sub list_plugin_families {
    my ($self) = @_;

    my $result  = $self->_get("/plugins/families");
    return $result ? @{$result} : ();
}

sub get_plugin_family_details {
    my ($self, %params) = @_;

    croak "missing id parameter" unless $params{id};

    my $family_id = delete $params{id};
    my $result = $self->_get("/plugins/families/$family_id", %params);
    return $result;
}

sub get_plugin_details {
    my ($self, %params) = @_;

    croak "missing id parameter" unless $params{id};

    my $plugin_id = delete $params{id};
    my $result = $self->_get("/plugins/plugin/$plugin_id", %params);
    return $result;
}

sub get_scanner_id {
    my ($self, %params) = @_;

    croak "missing name parameter" unless $params{name};

    my $scanner = first { $_->{name} eq $params{name}} $self->list_scanners();
    return unless $scanner;

    return $scanner->{id};
}

sub _get {
    my ($self, $path, %params) = @_;

    my $url = URI->new($self->{url} . $path);
    $url->query_form(%params);

    my $response = $self->{agent}->get($url);

    my $result = eval { from_json($response->content()) };

    if ($response->is_success()) {
        return $result;
    } else {
        if ($result) {
            croak "server error: " . $result->{error};
        } else {
            croak "communication error: " . $response->message()
        }
    }
}

sub _delete {
    my ($self, $path) = @_;

    my $response = $self->{agent}->delete($self->{url} . $path);

    my $result = eval { from_json($response->content()) };

    if ($response->is_success()) {
        return $result;
    } else {
        if ($result) {
            croak "server error: " . $result->{error};
        } else {
            croak "communication error: " . $response->message()
        }
    }
}

sub _post {
    my ($self, $path, %params) = @_;

    my $content = to_json(\%params);

    my $response = $self->{agent}->post(
        $self->{url} . $path,
        'Content-Type' => 'application/json',
        'Content'      => $content
    );

    my $result = eval { from_json($response->content()) };

    if ($response->is_success()) {
        return $result;
    } else {
        if ($result) {
            croak "server error: " . $result->{error};
        } else {
            croak "communication error: " . $response->message()
        }
    }
}

sub _put {
    my ($self, $path, %params) = @_;

    my $content = to_json(\%params);

    my $response = $self->{agent}->put(
        $self->{url} . $path,
        'Content-Type' => 'application/json',
        'Content'      => $content
    );

    my $result = eval { from_json($response->content()) };

    if ($response->is_success()) {
        return $result;
    } else {
        if ($result) {
            croak "server error: " . $result->{error};
        } else {
            croak "communication error: " . $response->message()
        }
    }
}

sub DESTROY {
    my ($self) = @_;
    $self->destroy_session() if $self->{agent}->default_header('X-Cookie');
}

1;
__END__

=head1 NAME

Net::Nessus::REST - REST interface for Nessus 6.0

=head1 DESCRIPTION

This module provides a Perl interface for communication with Nessus scanner
using REST interface.

=head1 SYNOPSIS

    use Net::Nessus::REST;

    my $nessus = Net::Nessus::REST->new(
        url => 'https://my.nessus:8834'
    ):

    $nessus->create_session(
        username => 'user',
        password => 's3cr3t',
    );

    my $policy_template_id = $nessus->get_template_id(
        name => 'basic',
        type => 'policy'
    );

    my $scan = $nessus->create_scan(
        uuid     => $policy_template_id,
        settings => {
            text_targets => '127.0.0.1',
            name         => 'localhost scan'
        }
    );

    $nessus->launch_scan(scan_id => $scan->{id});
    while ($nessus->get_scan_status(scan_id => $scan->{id} ne 'completed')) {
        sleep 10;
    }

    my $file_id = $nessus->export_scan(
        scan_id => $scan_id,
        format  => 'pdf'
    );

    $nessus->download_report(
        scan_id  => $scan_id,
        file_id  => $file_id,
        filename => 'localhost.pdf'
    );

=head1 CLASS METHODS

=head2 Net::Nessus::REST->new(url => $url, [ssl_opts => $opts, timeout => $timeout])

Creates a new L<Net::Nessus::Rest> instance.

=head1 INSTANCE METHODS

=head2 $nessus->create_session(username => $username, password => $password)

Creates a new session token for the given user.

See L<https://your.nessus.server:8834/nessus6-api.html#/resources/session/create> for details.

=head2 $nessus->destroy_session()

Logs the current user out and destroys the session.

See L<https://your.nessus.server:8834/nessus6-api.html#/resources/session/destroy> for details.

=head2 $nessus->list_policies()

Returns the policy list.

See L<https://your.nessus.server:8834/nessus6-api.html#/resources/policies/list> for details.

=head2 $nessus->get_policy_id(name => $name)

Returns the identifier for the policy with given name.

=head2 $nessus->list_scanners()

Returns the scanner list.

See L<https://your.nessus.server:8834/nessus6-api.html#/resources/scanners/list> for details.

=head2 $nessus->list_folders()

Returns the current user's scan folders.

See L<https://your.nessus.server:8834/nessus6-api.html#/resources/folders/list> for details.

=head2 $nessus->get_folder_id(name => $name)

Returns the identifier for the folder with given name.

=head2 $nessus->create_scan(uuid => $uuid, settings => $settings)

Creates a scan

See L<https://your.nessus.server:8834/nessus6-api.html#/resources/scans/create> for details.

=head2 $nessus->configure_scan(scan_id => $scan_id, uuid => $uuid, settings => $settings)

Changes the schedule or policy parameters of a scan.

See L<https://your.nessus.server:8834/nessus6-api.html#/resources/scans/configure> for details.

=head2 $nessus->delete_scan(scan_id => $scan_id)

Deletes a scan.

See L<https://your.nessus.server:8834/nessus6-api.html#/resources/scans/delete> for details.

=head2 $nessus->delete_scan_history(scan_id => $scan_id, history_id => $history_id)

Deletes historical results from a scan.

See L<https://your.nessus.server:8834/nessus6-api.html#/resources/scans/delete-history> for details.

=head2 $nessus->download_scan(scan_id => $scan_id, file_id => $file_id, filename => $filename)

Download an exported scan.
Without filename parameter it will return the content of the file

See L<https://your.nessus.server:8834/nessus6-api.html#/resources/scans/download> for details.

=head2 $nessus->export_scan(scan_id => $scan_id, format => $format)

Export the given scan.

See L<https://your.nessus.server:8834/nessus6-api.html#/resources/scans/export> for details.

=head2 $nessus->launch_scan(scan_id => $scan_id)

Launches a scan.

See L<https://your.nessus.server:8834/nessus6-api.html#/resources/scans/launch> for details.

=head2 $nessus->list_scans([folder_id => $id, last_modification_date => $date])

Returns the scan list.

See L<https://your.nessus.server:8834/nessus6-api.html#/resources/scans/list> for details.

=head2 $nessus->set_scan_read_status(scan_id => $scan_id, status => $status)

Changes the status of a scan.

See L<https://your.nessus.server:8834/nessus6-api.html#/resources/scans/read-status> for details.

=head2 $nessus->get_scan_details(scan_id => $scan_id, [history_id => $history_id])

Returns details for the given scan.

See L<https://your.nessus.server:8834/nessus6-api.html#/resources/scans/details> for details.

=head2 $nessus->get_scan_host_details(scan_id => $scan_id, host_id => $host_id, [history_id => $history_id])

Returns details for the given host.

See L<https://your.nessus.server:8834/nessus6-api.html#/resources/scans/host-details> for details.

=head2 $nessus->get_scan_export_status(scan_id => $scan_id, file_id => $file_id)

Check the file status of an exported scan.

See L<https://your.nessus.server:8834/nessus6-api.html#/resources/scans/export-status> for details.

=head2 $nessus->get_scan_plugin_output(scan_id => $scan_id, host_id => $host_id, plugin_id => $plugin_id, [history_id => $history_id])

Returns the output for a given plugin.

See L<https://your.nessus.server:8834/nessus6-api.html#/resources/scans/plugin-output> for details.

=head2 $nessus->get_scan_id(name => $name)

Returns the identifier for the scan with given name.

=head2 $nessus->get_scan_status(scan_id => $scan_id)

Returns the status for given scan.

=head2 $nessus->get_scan_history_id(scan_id => $scan_id, scan_uuid => $scan_uuid)

Returns the identifier for the historical results for given scan and run.

=head2 $nessus->list_templates(type => $type)

Returns the template list.

See L<https://your.nessus.server:8834/nessus6-api.html#/resources/editor/list> for details.

=head2 $nessus->get_template_id(type => $type, name => $name)

Returns the identifier for template with given name.

=head2 $nessus->get_plugin_details( plugin_id => $plugin_id )

returns the details of a plugin

See L<https://your.nessus.server:8834/nessus6-api.html#/resources/plugins/plugin-details> for details.

=head2 $nessus->list_plugin_families( )

returns a list of plugin families

See L<https://your.nessus.server:8834/nessus6-api.html#/resources/plugins/families> for details.

=head2 $nessus->get_plugin_family_details( )

returns the details about a plugin family

See L<https://your.nessus.server:8834/nessus6-api.html#/resources/plugins/family-details> for details.

=head2 $nessus->get_scanner_id( name => $name )

returns the identifier for the scanner with given name.

=head1 LICENSE

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
