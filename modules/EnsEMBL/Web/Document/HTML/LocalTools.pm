package EnsEMBL::Web::Document::HTML::LocalTools;

# Generates the local context tools - configuration, data export, etc.

use strict;
use base qw(EnsEMBL::Web::Document::HTML);
use EnsEMBL::Web::RegObj;

sub add_entry {
  my $self = shift;
  push @{$self->{'_entries'}}, {@_};
}

sub entries {
  my $self = shift;
  return $self->{'_entries'}||[];
}

sub render {
  my $self = shift;
  
  return unless @{$self->entries};
  
  my %icons = (
    'Configure this page' => 'config',
    'Manage your data'    => 'data',
    'Export data'         => 'export',
    'Bookmark this page'  => 'bookmark'
  );
  
  my $html = ' 
  <div id="local-tools" style="display:none">
  ';
  
  foreach (@{$self->entries}) {
    my $icon = qq{<img src="/i/$icons{$_->{'caption'}}.png" alt="" style="vertical-align:middle;padding:0px 4px" />};
    
    if ($_->{'class'} eq 'disabled') {
      $html .= qq{<p class="disabled" title="$_->{'title'}">$icon$_->{'caption'}</p>};
    } else {
      my $attrs = $_->{'class'};
      my $rel = lc $_->{'rel'};
      $attrs .= ($attrs ? ' ' : '') . 'external' if $rel eq 'external';
      $attrs = qq{class="$attrs"} if $attrs;
      $attrs .= ' style="display:none"' if $attrs =~ /modal_link/;
      $attrs .= qq{ rel="$rel"} if $rel;
      
      $html .= qq{
        <p><a href="$_->{'url'}" $attrs>$icon$_->{'caption'}</a></p>};
    }
  }
  
  $html .= '
  </div>';
  
  $self->print($html);

### EG want to acknowledge collaborators. 
# If you add ACKNOWLEDGEMENT entry to an ini file then you get
# a box with the ACKNOWLEDGEMENT text at the bottom of LH menu. It will link to /info/acknowledgement.html which 
# you will have to create
# If you add DB_BUILDER entry to an ini file then you get
# a box with the text DB built by XXX at the bottom of LH menu. It will link to the current species' homepage

  if (my $ack_text = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->ACKNOWLEDGEMENT) {
      $self->print( q(<div>
		      <ul>) );
      $self->printf('<li style="list-style:none" title="%s"><a href="%s">%s</a></li>',$ack_text,'/info/acknowledgement.html', $ack_text);

      $self->print( q(
		      </ul>
		      </div>) );
  }

  if (my $db_provider = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->DB_BUILDER) {
      my $spath = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->species_path($ENV{ENSEMBL_SPECIES});
      
      $self->print( q(<div>
		      <ul>) );
      $self->printf('<li style="list-style:none"><a href="%s/Info/Index">DB built by %s</a></li>', $spath , $db_provider);

      $self->print( q(
		      </ul>
		      </div>) );
  }


}

1;
