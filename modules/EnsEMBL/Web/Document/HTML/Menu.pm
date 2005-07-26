package EnsEMBL::Web::Document::HTML::Menu;
use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;

@EnsEMBL::Web::Document::HTML::Menu::ISA = qw(EnsEMBL::Web::Document::HTML);
use Data::Dumper qw(Dumper);

sub new { return shift->SUPER::new( 'blocks' => {} , 'block_order' => [],  'site_name' => '??????'  ); }

sub site_name :lvalue { $_[0]{'site_name'}; }
sub archive   :lvalue { $_[0]{'archive'}; }
sub inst_logo        :lvalue { $_[0]{'inst_logo'}; }
sub inst_logo_href   :lvalue { $_[0]{'inst_logo_href'}; }
sub inst_logo_alt    :lvalue { $_[0]{'inst_logo_alt'}; }
sub inst_logo_width  :lvalue { $_[0]{'inst_logo_width'}; }
sub inst_logo_height :lvalue { $_[0]{'inst_logo_height'}; }
sub collab_logo        :lvalue { $_[0]{'collab_logo'}; }
sub collab_logo_href   :lvalue { $_[0]{'collab_logo_href'}; }
sub collab_logo_alt    :lvalue { $_[0]{'collab_logo_alt'}; }
sub collab_logo_width  :lvalue { $_[0]{'collab_logo_width'}; }
sub collab_logo_height :lvalue { $_[0]{'collab_logo_height'}; }

sub add_block {
  my( $self, $code, $type, $caption, %options ) = @_;
  return if exists $self->{'blocks'}{$code};
  $self->{'blocks'}{$code} = { 
    'caption' => $caption,
    'type'    => $type,
    'entries' => [],
    'options' => \%options
  };
  push @{$self->{'block_order'}}, $code;
}

sub block {
  my( $self, $code ) = @_;
  return exists $self->{'blocks'}{$code};
}

sub add_entry {
  my( $self, $code, %options ) = @_;
  return unless exists $self->{'blocks'}{$code};
  push @{$self->{'blocks'}{$code}{'entries'}}, \%options;
}

sub render {
  my $self = shift;
  $self->print( qq(\n<div id="related"><div id="related-box">) );
  foreach my $block_key (@{$self->{'block_order'}}) {
    my $block = $self->{'blocks'}{$block_key};
    $self->printf( qq(\n  <h2>%s</h2>), $block->{'options'}{'raw'} ? $block->{'caption'} : CGI::escapeHTML( $block->{'caption'} ) );
    my $block_render_function = "render_type_$block->{'type'}";
    if( $self->can( $block_render_function ) ) {
      $self->$block_render_function( $block );
    } else {
      $self->block_render_bulleted( $block->{'entries'} );
    }
  }

  # get appropriate affiliation logos from ini
  if ($self->inst_logo || $self->collab_logo) {
    $self->print( qq(\n<h2 style="padding:4px; margin-top: 2em">\n));
    if ($self->inst_logo) {
        $self->printf( qq(<a href="%s"><img style="padding-left:15px" src="%s" width="%s" height="%s" alt="%s" title="%s" /></a>), $self->inst_logo_href, $self->inst_logo, $self->inst_logo_width, $self->inst_logo_height, $self->inst_logo_alt, $self->inst_logo_alt);
    }
    if ($self->collab_logo) {
        $self->printf( qq(<a href="%s"><img style="padding-left:15px" src="%s" width="%s" height="%s" alt="%s" title="%s" /></a>), $self->collab_logo_href, $self->collab_logo, $self->collab_logo_width, $self->collab_logo_height, $self->collab_logo_alt, $self->collab_logo_alt);
    }
    $self->print('</h2>');
  }

  $self->print( qq(\n</div></div>) );
}

sub _atag {
  my( $self, $entry ) = @_;
  my $_atag = '';
  if( $entry->{'form'} ) { 
    $_atag .= $entry->{'form'};  
    return $_atag;
  } else {
    foreach( qw(title href) ) {
      $_atag.= sprintf( qq( $_="%s"), CGI::escapeHTML( $entry->{$_}) ) if exists $entry->{$_};
    }
    if( $entry->{'href'} =~ m|^https?://([^/]+)| ) {
      $_atag .= qq( target="$1");
    }
    my $V = exists( $entry->{'raw'} ) ? $entry->{'text'} : CGI::escapeHTML( $entry->{'text'} );
    return $_atag ? "<a$_atag>$V</a>" : $V;
  }
}

sub block_render_bulleted {
  my( $self, $entries ) = @_;
  $self->print( qq(\n  <ul>) );
  foreach my $entry (@$entries) {
    my $extra = $entry->{'icon'} ? qq( style="list-style: url($entry->{'icon'})") : "";
    if( exists( $entry->{'options'} ) ) {
      my $style = $entry->{'popup'} ne 'no' ? " dropdown" : '';
      $self->printf( qq(\n    <li class="bullet$style"$extra>%s\n      <ul>), $self->_atag($entry) );
      foreach( @{$entry->{'options'}} ) {
          $self->printf( qq(\n      <li class="m">%s</li>), $self->_atag( $_ ) ); 
      }
      $self->print( qq(\n    </ul>\n</li>));
    } else {
      $self->printf( qq(\n     <li class="bullet"$extra>%s</li>), $self->_atag( $entry ));
    }
  }
  $self->print( qq(\n  </ul>));
}

sub render_type_form {
    my( $self, $block ) = @_;
    my $entries = $block->{'entries'};

    my $form = EnsEMBL::Web::Form->new( $block->{'options'}->{name}, $block->{'options'}->{action}, $block->{'options'}->{method});
    my @hidden_params = split /&amp;/, $block->{'options'}->{hidden};
    foreach my $p (@hidden_params) {
	my ($name, $value) = split /=/, $p;
	$form->add_element( 'type' => 'Hidden', 'value' => $value, 'name'=>$name );     
    }

    foreach my $entry (@$entries) {
	$form->add_element( 'type' => 'Image', 'value' => $entry->{value}, 'name'=>$entry->{name}, 'src'=>$entry->{src} );     
    }

    my $html = "<br/>".$form->render();
    $self->print($html);
}

1;

