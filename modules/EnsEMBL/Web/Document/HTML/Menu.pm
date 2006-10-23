package EnsEMBL::Web::Document::HTML::Menu;
use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub new {
  return shift->SUPER::new(
    'blocks'      => {},
    'block_order' => [],
    'site_name'   => '??????' ,
    'logos'       => [],
    'miniad'      => '',
  );
}

sub site_name          :lvalue { $_[0]{'site_name'}; }
sub archive            :lvalue { $_[0]{'archive'}; }

sub push_logo {
  my( $self, %conf ) = @_;
  push @{$self->{'logos'}}, \%conf;
}

##############################################################################
# Functions to manage menu blocks on the webpage on the LHS menu
#   $menu->add_block(              $code, $type, $caption,   %options   )
#   $menu->change_block_attribute( $code, $attribute, $new_value )
#   $menu->delete_block(           $code )
#   $menu->block(                  $code )
##############################################################################

sub add_block {
  my( $self, $code, $type, $caption, %options ) = @_;
  my @C = caller(0);
  return if exists $self->{'blocks'}{$code};
  $self->{'blocks'}{$code} = { 
    'caption' => $caption,
    'type'    => $type,
    'entries' => [],
    'options' => \%options
  };
  my $priority = $options{'priority'}||0;
  $self->{'block_order'}[$priority]||=[];
  push @{$self->{'block_order'}[$priority]}, $code;
}

sub change_block_attribute { 
  my( $self, $code, $attr, $new_value ) = @_;
  return unless $self->{'blocks'}{$code};
  if( $attr eq 'priority' ) {
    $new_value ||= 0;
    my $old_priority = $self->{'blocks'}{$code}{'options'}{'priority'};
    return if $new_value == $old_priority;
    $self->{'block_order'}[$old_priority] = [grep{$_ ne $code} @{$self->{'block_order'}[$old_priority]}];
    push @{$self->{'block_order'}[$new_value]}, $code;
  }
  if( exists($self->{'blocks'}{$code}{$attr}) ) {
    $self->{'blocks'}{$code}{$attr} = $new_value;
  } else {
    $self->{'blocks'}{$code}{'options'}{$attr} = $new_value;
  }
}

sub delete_block {
  my( $self, $code ) = @_;
  my $priority = $self->{'blocks'}{$code}{'options'}{'priority'}||0;
  delete $self->{'blocks'}{$code};
  $self->{'block_order'}[$priority] = [ grep { $_ ne $code } @{ $self->{'block_order'}[$priority] } ];
}

sub block {
  my( $self, $code ) = @_;
  return exists $self->{'blocks'}{$code};
}

##############################################################################
# Functions to manage menu entries on the webpage on the LHS menu
#   $menu->add_entry(        $code, %options )
#   $menu->add_entry_first(  $code, %options )
#   $menu->add_entry_after(  $code, $key,  %options )
#   $menu->add_entry_before( $code, $key,  %options )
#   $menu->delete_entry(     $code, $key )
#   $menu->entry(            $code, $key )
##############################################################################

sub add_entry {
  my( $self, $code, %options ) = @_;
  return unless exists $self->{'blocks'}{$code};
  push @{$self->{'blocks'}{$code}{'entries'}}, \%options;
}

sub add_entry_first {
  my( $self, $code, %options ) = @_;
  return unless exists $self->{'blocks'}{$code};
  unshift @{$self->{'blocks'}{$code}{'entries'}}, \%options;
}

sub add_entry_after {
  my( $self, $code, $key, %options ) = @_;
  return unless exists $self->{'blocks'}{$code};
  my $C = 0;
  foreach( @{$self->{'blocks'}{$code}{'entries'}} ) {
    $C++;
    last if $_->{'code'} eq $key; 
  }
  splice @{$self->{'blocks'}{$code}{'entries'}}, $C, 0, \%options; 
}

sub add_entry_before {
  my( $self, $code, $key, %options ) = @_;
  return unless exists $self->{'blocks'}{$code};
  my $C = 0;
  foreach( @{$self->{'blocks'}{$code}{'entries'}} ) {
    last if $_->{'code'} eq $key;
    $C++;
  }
  splice @{$self->{'blocks'}{$code}{'entries'}}, $C, 0, \%options;
}

sub change_entry_attribute {

}


sub delete_entry {
  my( $self, $code, $key ) = @_;
  return unless exists $self->{'blocks'}{$code};
  $self->{'blocks'}{$code}{'entries'} = [ grep { $_->{'code'} ne $key } @{$self->{'blocks'}{$code}{'entries'}} ];
}

sub entry {
  my( $self, $code, $key ) = @_;
  return unless exists $self->{'blocks'}{$code};
  foreach( @{$self->{'blocks'}{$code}{'entries'}} ) {
    return $_ if $_->{'code'} eq $key;
  }
  return undef;
}

sub add_miniad {
  my ($self, $html) = @_;
  return unless $html;
  $self->{'miniad'} = $html;
}

sub delete_miniad {
  my $self = shift;
  $self->{'miniad'} = '';
}

sub render {
  my $self = shift;
  $self->print( qq(\n<div id="related"><div id="related-box">) );
  foreach my $block_key (map {@$_} grep {$_} @{$self->{'block_order'}}) {
    my $block = $self->{'blocks'}{$block_key};
    next unless $block;
    $self->printf(
      qq(\n  <h2>%s</h2>),
      $block->{'options'}{'raw'} ? $block->{'caption'} : CGI::escapeHTML( $block->{'caption'} )
    );
    my $block_render_function = "render_type_$block->{'type'}";
    if( $self->can( $block_render_function ) ) {
      $self->$block_render_function( $block );
    } else {
      $self->block_render_bulleted( $block->{'entries'} );
    }
  }

  # get appropriate affiliation logos from ini
  if( @{$self->{'logos'}} ) {
    $self->print( qq(\n<h2 style="padding:4px; margin-top: 2em">\n));
    foreach my $logo ( @{$self->{'logos'}}) {
      $self->printf(
        qq(<a href="%s"><img style="padding-left:15px" src="%s" width="%s" height="%s" alt="%s" title="%s" /></a>),
        map { $logo->{$_}||'' } qw(href src width height alt alt)
      );
    }
    $self->print('</h2>');
  }

  ## include a miniad
  $self->print($self->{'miniad'}) if $self->{'miniad'};

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
      my $base_url = EnsEMBL::Web::SpeciesDefs->ENSEMBL_BASE_URL; 
      if ($entry->{'href'} !~ m/$base_url/) {
        $_atag .= qq( target="$1");
      }
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
      $self->printf( qq(\n    <li class="bullet$style"$extra>%s\n), $self->_atag($entry) );
      $self->print( qq(    <ul>) ) unless scalar(@{$entry->{'options'}}) < 1;
      foreach( @{$entry->{'options'}} ) {
          $self->printf( qq(\n      <li class="m">%s</li>), $self->_atag( $_ ) ); 
      }
      $self->print( qq(\n    </ul>) ) unless scalar(@{$entry->{'options'}}) < 1;
      $self->print( qq(\n</li>));
    } else {
      $self->printf( qq(\n     <li class="bullet"$extra>%s</li>), $self->_atag( $entry ));
    }
  }
  $self->print( qq(\n  </ul>));
}

sub render_type_raw {
  my( $self, $block ) = @_;
  $self->print( $block->{'options'}{'html'} );
}

sub render_type_form {
  my( $self, $block ) = @_;
  my $entries = $block->{'entries'};

  my $form = EnsEMBL::Web::Form->new(
    $block->{'options'}->{name},
    $block->{'options'}->{action},
    $block->{'options'}->{method}
  );
  my @hidden_params = split /&amp;/, $block->{'options'}->{hidden};
  foreach my $p (@hidden_params) {
    my ($name, $value) = split /=/, $p;
    $form->add_element( 'type' => 'Hidden', 'value' => $value, 'name'=>$name );     
  }

  foreach my $entry (@$entries) {
    $form->add_element( 'type' => 'Image', 'value' => $entry->{value}, 'name'=>$entry->{name}, 'src'=>$entry->{src} );     
  }

  my $html = $form->render();
  $self->print($html);
}

#######################################################################
# Returns a list of codes for each block in the menu, sorted into 
# priority order
sub blocks{
  my $self = shift;
  return( map {@$_} grep {$_} @{$self->{'block_order'}} );
}

#######################################################################
# Returns a list of codes for each entry in the menu, sorted into      
# priority order
# Can specify one or more block codes
sub entries{
  my $self = shift;
  my @blocks = @_;
  unless( @blocks ){ @blocks = $self->blocks }

  my @entries;
  foreach my $block( @blocks ){
    push( @entries, 
          map{ $_->{'code'}}
          @{$self->{'blocks'}{$block}{'entries'}} );
  }
  return @entries;
}

1;

__END__


