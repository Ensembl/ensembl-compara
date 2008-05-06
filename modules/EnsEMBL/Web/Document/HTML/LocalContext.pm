package EnsEMBL::Web::Document::HTML::LocalContext;

### Generates the local context navigation menu, used in dynamic pages

use strict;
use base qw(EnsEMBL::Web::Document::HTML);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new( 'tree' => undef, 'active' => undef, 'caption' => 'Local context' );
  return $self;
}

sub tree {
  ### a
  my $self = shift;
  $self->{tree} = shift if @_;
  return $self->{tree};
}

sub active {
  ### a
  my $self = shift;
  $self->{active} = shift if @_;
  return $self->{active};
}

sub caption {
  ### a
  my $self = shift;
  $self->{caption} = shift if @_;
  return $self->{caption};
}

sub render {
  my $self = shift;
  my $t = $self->tree;
  warn $t;
  return unless $t;
  warn %$t;
  my $r = 0;
  my $previous_node;
  my $active = $self->active;
  my $active_node = $t->get_node( $active );
  my $active_l    = $active_node->left;
  my $active_r    = $active_node->right;
  my $counts = {};
  $self->printf( q(<dl id="local">
  <dt>%s</dt>), $self->caption );
  foreach my $node ( $t->nodes ) {
    $r = $node->right if $node->right > $r;
    $self->print( "
</dl>
  </dd>\n" x ($node->left - $previous_node->right-1) ) if $previous_node && $node->left > $previous_node->right;
    my $name = $node->data->{caption};
       $name =~ s/\[\[counts::(\w+)\]\]/$counts->{$1}/eg;
       $name = CGI::escapeHTML( $name );
    if( $node->data->{'url'} ) {
      $name = sprintf( '<a href="%s">%s</a>', $node->data->{'url'}, $name );
    }
    if( $node->is_leaf ) {
      $self->printf( q(
  <dd%s>%s</dd>), $node->key eq $active ? ' class="active"' :'', $name );
    } else {
      $self->printf( q(
  <dd class="%s">%s
<dl>), $node->left <= $active_l && $node->right >= $active_r ? 'open' : 'closed', $name );
    }
    $previous_node = $node;
  }
  $self->print( q(
</dl>
  </dd>) x ($r-$previous_node->right)
  ); 
  $self->print( q(
</dl>) );
}

return 1;
