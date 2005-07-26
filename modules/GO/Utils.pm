# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

package GO::Utils;

use Exporter;

@ISA = qw(Exporter);

@EXPORT_OK = qw(rearrange remove_duplicates merge_hashes get_method_ref
	       get_param pset2hash dd spell_greek max check_obj_graph);

use strict;
use Carp;
use Data::Dumper;

=head2 rearrange()

 Usage    : n/a
 Function : Rearranges named parameters to requested order.
 Returns  : @params - an array of parameters in the requested order.
 Argument : $order : a reference to an array which describes the desired
                     order of the named parameters.
            @param : an array of parameters, either as a list (in
                     which case the function simply returns the list),
                     or as an associative array (in which case the
                     function sorts the values according to @{$order}
                     and returns that new array.

 Exceptions : carps if a non-recognised parameter is sent

=cut

sub rearrange {
  # This function was taken from CGI.pm, written by Dr. Lincoln
  # Stein, and adapted for use in Bio::Seq by Richard Resnick.
  # ...then Chris Mungall came along and adapted it for BDGP
  my($order,@param) = @_;

  # If there are no parameters, we simply wish to return
  # an undef array which is the size of the @{$order} array.
  return (undef) x $#{$order} unless @param;

  # If we've got parameters, we need to check to see whether
  # they are named or simply listed. If they are listed, we
  # can just return them.
  return @param unless (defined($param[0]) && $param[0]=~/^-/);

  # Now we've got to do some work on the named parameters.
  # The next few lines strip out the '-' characters which
  # preceed the keys, and capitalizes them.
  my $i;
  for ($i=0;$i<@param;$i+=2) {
      if (!defined($param[$i])) {
	  carp("Hmmm in $i ".join(";", @param)." == ".join(";",@$order)."\n");
      }
      else {
	  $param[$i]=~s/^\-//;
	  $param[$i]=~tr/a-z/A-Z/;
      }
  }
  
  # Now we'll convert the @params variable into an associative array.
  my(%param) = @param;

  my(@return_array);
  
  # What we intend to do is loop through the @{$order} variable,
  # and for each value, we use that as a key into our associative
  # array, pushing the value at that key onto our return array.
  my($key);

  foreach $key (@{$order}) {
      $key=~tr/a-z/A-Z/;
      my($value) = $param{$key};
      delete $param{$key};
      push(@return_array,$value);
  }
  
  # catch user misspellings resulting in unrecognized names
  my(@restkeys) = keys %param;
  if (scalar(@restkeys) > 0) {
       carp("@restkeys not processed in rearrange(), did you use a
       non-recognized parameter name ? ");
  }
  return @return_array;
}




=head2 get_param()

Usage    : get_param('name',(-att1=>'ben',-name=>'the_name'))
Function : Fetches a  named parameter.
Returns  : The value of the requested parameter.
Argument : $name : The name of the the parameter desired
           @param : an array of parameters, as an associative array 
Exceptions : carps if a non-recognised parameter is sent

Based on rearrange(), which is originally from CGI.pm by Lincoln
Stein and BioPerl by Richard Resnick.  See rearrange() for details.

=cut

sub get_param
  {

  # This function was taken from CGI.pm, written by Dr. Lincoln
  # Stein, and adapted for use in Bio::Seq by Richard Resnick.
  # ...then Chris Mungall came along and adapted it for BDGP
    # ... and ben berman added his 2 cents.

  my($name,@param) = @_;

  # If there are no parameters, we simply wish to return
  # false.
  return '' unless @param;

  # If we've got parameters, we need to check to see whether
  # they are named or simply listed. If they are listed, we
  # can't return anything.
  return '' unless (defined($param[0]) && $param[0]=~/^-/);

  # Now we've got to do some work on the named parameters.
  # The next few lines strip out the '-' characters which
  # preceed the keys, and capitalizes them.
  my $i;
  for ($i=0;$i<@param;$i+=2) {
        $param[$i]=~s/^\-//;
        $param[$i] = uc($param[$i]);
  }
  
  # Now we'll convert the @params variable into an associative array.
  my(%param) = @param;

  # We capitalize the key, and use it as a key into our
  # associative array
  my $key = uc($name);
  my $val = $param{$key};

  return $val;
}






























=head2 remove_duplicates

remove duplicate items from an array

 usage: remove_duplicates(\@arr)

affects the array passed in, and returns the modified array

=cut

sub remove_duplicates {
    
    my $arr_r = shift;
    my @arr = @{$arr_r};
    my %h = ();
    my $el;
    foreach $el (@arr) {
	$h{$el} = 1;
    }
    my @new_arr = ();
    foreach $el (keys %h) {
	push (@new_arr, $el);
    }
    @{$arr_r} = @new_arr;
    @new_arr;
}

=head1 merge_hashes

joins two hashes together

 usage: merge_hashes(\%h1, \%h2);

%h1 will now contain the key/val pairs of %h2 as well. if there are
key conflicts, %h2 values will take precedence.

=cut

sub merge_hashes {
    my ($h1, $h2) = @_;
    map {
	$h1->{$_} = $h2->{$_};
    } keys %{$h2};
    return $h1;
}

=head1 get_method_ref

 returns a pointer to a particular objects method
 e.g.   my $length_f = get_method_ref($seq, 'length');
        $len = &$length_f();

=cut

sub get_method_ref {
    my $self = shift;
    my $method = shift;
    return sub {return $self->$method(@_)};
}


=head2 pset2hash

  Usage   - my $h = pset2hash([{name=>"id", value=>"56"}, {name=>"name", value=>"jim"}]);
  Returns - hashref
  Args    - arrayref of name/value keyed hashrefs

=cut

sub pset2hash {
    my $pset = shift;
    my $h = {};
    # printf STDERR "REF=%s;\n", ref($pset);
    if (ref($pset) eq "ARRAY") {
	map {$h->{$_->{name}} = $_->{value}} @$pset;
    }
    elsif (ref($pset) eq "HASH") {
	$h = $pset;
    }
    else {
        $h = $pset;
    }
    return $h;
}

sub dd {
    my $obj = shift;
    my $d= Data::Dumper->new(['obj',$obj]);
    print $d->Dump;
}
  
=head2 spell_greek

takes a word as a parameter and spells out any greek symbols encoded
within (eg s/&agr;/alpha/g)

=cut

sub spell_greek
{
    my $name = shift;

    $name =~ s/&agr\;/alpha/g;
    $name =~ s/&Agr\;/Alpha/g;
    $name =~ s/&bgr\;/beta/g;
    $name =~ s/&Bgr\;/Beta/g;
    $name =~ s/&ggr\;/gamma/g;
    $name =~ s/&Ggr\;/Gamma/g;
    $name =~ s/&dgr\;/delta/g;
    $name =~ s/&Dgr\;/Delta/g;
    $name =~ s/&egr\;/epsilon/g;
    $name =~ s/&Egr\;/Epsilon/g;
    $name =~ s/&zgr\;/zeta/g;
    $name =~ s/&Zgr\;/Zeta/g;
    $name =~ s/&eegr\;/eta/g;
    $name =~ s/&EEgr\;/Eta/g;
    $name =~ s/&thgr\;/theta/g;
    $name =~ s/&THgr\;/Theta/g;
    $name =~ s/&igr\;/iota/g;
    $name =~ s/&Igr\;/Iota/g;
    $name =~ s/&kgr\;/kappa/g;
    $name =~ s/&Kgr\;/Kappa/g;
    $name =~ s/&lgr\;/lambda/g;
    $name =~ s/&Lgr\;/Lambda/g;
    $name =~ s/&mgr\;/mu/g;
    $name =~ s/&Mgr\;/Mu/g;
    $name =~ s/&ngr\;/nu/g;
    $name =~ s/&Ngr\;/Nu/g;
    $name =~ s/&xgr\;/xi/g;
    $name =~ s/&Xgr\;/Xi/g;
    $name =~ s/&ogr\;/omicron/g;
    $name =~ s/&Ogr\;/Omicron/g;
    $name =~ s/&pgr\;/pi/g;
    $name =~ s/&Pgr\;/Pi/g;
    $name =~ s/&rgr\;/rho/g;
    $name =~ s/&Rgr\;/Rho/g;
    $name =~ s/&sgr\;/sigma/g;
    $name =~ s/&Sgr\;/Sigma/g;
    $name =~ s/&tgr\;/tau/g;
    $name =~ s/&Tgr\;/Tau/g;
    $name =~ s/&ugr\;/upsilon/g;
    $name =~ s/&Ugr\;/Upsilon/g;
    $name =~ s/&phgr\;/phi/g;
    $name =~ s/&PHgr\;/Phi/g;
    $name =~ s/&khgr\;/chi/g;
    $name =~ s/&KHgr\;/Chi/g;
    $name =~ s/&psgr\;/psi/g;
    $name =~ s/&PSgr\;/Psi/g;
    $name =~ s/&ohgr\;/omega/g;
    $name =~ s/&OHgr\;/Omega/g;
    $name =~ s/<up>/\[/g;
    $name =~ s/<\/up>/\]/g;
    $name =~ s/<down>/\[\[/g;
    $name =~ s/<\/down>/\]\]/g;

    return $name;
}


=head2 check_obj_graph

  Usage   -
  Returns - true if cycle detected
  Args    - any object

=cut

sub check_obj_graph {
    my $object = shift;
    
    my $h = {};
    my $cnt = 1;
    my @nodes = ({obj=>$object,path=>[]});
    my @path = ();
    my $cycle = 0;
    while (!$cycle && @nodes) {
	my $node = shift @nodes;
	my $obj = $node->{obj};
	my $id = sprintf("%s", $node->{obj});
	if (ref($obj) && $id !~ /GLOB/) {
	    
	    if (!$h->{$id}) {
		$h->{$id} = $cnt;
		$cnt++;
	    }
	    
	    # check for cycles
	    if (grep {my $idelt = sprintf("%s", $_); $idelt eq $id}
		@{$node->{path}}) {
		$cycle = $node;
	    }

	    printf 
	      "* OB:%5s %20s [%s]\n",
	      $h->{$id},
	      $obj,
	      join(", ", map {$h->{$_}} @{$node->{path}});

	    my @newobjs = ();
	    if (ref($obj) eq "ARRAY") {
		@newobjs = @$obj;
	    }
##	    if (ref($obj) eq "HASH") {
	    elsif (ref($obj) eq "GLOB") {
	    }
	    else {
		@newobjs = values %$obj;
	    }
	    map {
		my @newpath = (@{$node->{path}}, $obj);
		my $newnode = {obj=>$_, path=>\@newpath};
		push(@nodes, $newnode);
	    } @newobjs;
	}
    }
    return $cycle;

}



sub max
  {
    my @items = @_;

    my $max;
    my $item;
    foreach $item (@items)
      {
        if (!defined($max))
          {
            $max = $item;
          }
        else
          {
            $max = $item if ($item > $max);
          }
      }

    return $max;
  }



1;
