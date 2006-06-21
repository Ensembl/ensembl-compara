package EnsEMBL::Web::Component::Help;

use EnsEMBL::Web::Component;
use EnsEMBL::Web::Form;

our @ISA = qw( EnsEMBL::Web::Component);
use strict;
use warnings;
no warnings "uninitialized";

sub _wrap_form {
  my ( $panel, $object, $node ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);
  $html .= $panel->form($node)->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
}

sub hv_intro      { _wrap_form($_[0], $_[1], 'hv_intro'); }
sub hv_contact    { _wrap_form($_[0], $_[1], 'hv_contact'); }

sub hv_multi {
  my($panel,$object) = @_;
  my $kw = $object->param('search');
  my $list_type;
  if ($object->species_defs->ENSEMBL_MODULAR_HELP) {
    $list_type = 'dl';
  }
  else {
    $list_type = 'ul';
  }
  $panel->print(qq(
  <p>Your search for "$kw" is found in the following entries:</p>
  <$list_type>));
  foreach( @{$object->results}) {
    if ($object->species_defs->ENSEMBL_MODULAR_HELP) {
      $panel->printf( qq(\n    <dt><a href="%s">%s</a></dt><dd>%s</dd>), $object->_help_URL($_->{'keyword'}), $_->{'title'}, $_->{'summary'} );
    }
    else {
      $panel->printf( qq(\n    <li><a href="%s">%s</a></li>), $object->_help_URL($_->{'keyword'}), $_->{'title'} );
    }
  } 
  $panel->print(qq(\n</$list_type>));
  return 1;
}

sub hv_single {
  my($panel,$object) = @_;
  my $article = $object->results->[0];

  my $html = '<h2>'.$$article{'title'}.'</h2>';
  if ($object->species_defs->ENSEMBL_MODULAR_HELP) {
    if ($$article{'intro'}) {
      $html .= qq(<h3 class="boxed">Introduction</h3>);
      $html .= $$article{'intro'};
    }
    ## do individual chunks
    if ($$article{'items'} && scalar(@{$$article{'items'}}) > 0) {
      my @items = @{$$article{'items'}};
      foreach my $item (@items) {
        $html .= '<h3 class="boxed">'.$$item{'header'}."</h3>\n".$$item{'content'}."\n\n";
      }
    }
  }
  else {
    $html .= "\n".$$article{'content'};
  }
  $panel->print($html);
  return 1;
}

sub hv_thanks {
  my($panel,$object) = @_;
  my $sitetype = ucfirst(lc($object->species_defs->ENSEMBL_SITETYPE)) || 'Ensembl';
  $panel->print(qq(
<p>Your message was successfully sent to the $sitetype Site Helpdesk Administration Team. They will get back to you in due course.</p>
<p>Helpdesk</p>));
  return 1;
}


1;
