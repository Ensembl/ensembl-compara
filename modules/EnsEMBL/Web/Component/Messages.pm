=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Component::Messages;

### Abstract parent class for session messages

use strict;
use warnings;

use EnsEMBL::Web::Constants;
use EnsEMBL::Web::Attributes;

use parent qw(EnsEMBL::Web::Component);

sub priority :Abstract;

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self = shift;

  my $session   = $self->hub->session or return; # no session created yet
  my @priority  = $self->priority;
  my $records   = $session->records({'type' => 'message', 'function' => [ scalar @priority ? @priority : EnsEMBL::Web::Constants::MESSAGE_PRIORITY ]});
  my $html      = '';
  my %messages;

  # Group messages by type
  # Set a default order of 100 - we probably aren't going to have 100 messages on the page at once, and this allows us to force certain messages to the bottom by giving order > 100
  push @{$messages{$_->{'function'}}}, $_->{'message'} for sort { $a->{'order'} || 100 <=> $b->{'order'} || 100 } map $_->data, @$records;

  foreach (@priority) {
    next unless $messages{$_};

    my $func    = $self->can($_) ? $_ : '_info';
    my $caption = $func eq '_info' ? 'Information' : ucfirst substr $func, 1, length $func;
    my $msg     = join '</li><li>', @{$messages{$_}};
       $msg     = "<ul><li>$msg</li></ul>" if scalar @{$messages{$_}} > 1;

    $html .= $self->$func($caption, $msg);
    $html .= '<br />';
  }

  $session->delete_records($records);

  return $self->renderer->{'_modal_dialog_'}
    ? qq(<div class="session_messages">$html</div>)
    : qq(<div class="session_messages js_panel"><input type="hidden" class="panel_type" value="Message">$html</div>);
}

1;
