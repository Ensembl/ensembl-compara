#!/usr/bin/perl -w

package GO::AppHandles::AppHandleCachingImpl;

=head1 NAME

  GO::AppHandles::AppHandleCachingImpl;

=head1 SYNOPSIS

  $factory = GO::AppHandles::AppHandleCachingImpl->new( $factory );

  All the public API's of this class should come through the
  GO::AppHandle class, and are documented there.

=head1 DESCRIPTION

  implementation of AppHandle for the GO API, which delegates all
  function to another AppHandle, but caches all results in
  memory. Generally speaking this trades space for speed. If you use
  large parts of the GO database, this class will use extremely large
  amounts of memory.

  This class is somewhat experimental at the moment. It has a number
  of flaws.  In particular, it does not implement a true flyweight, so
  that for instance a single GO Term is represented by a single
  GO::Model::Term object. Different methods, or single methods with
  different parameters, which return the same GO term, will return
  different Term objects. At the moment some of the methods are
  flyweighted. It is possible to flyweight others, but in this case
  they will sometimes return objects with the wrong values! You can
  read the in code documentation for details.

  My own use of the GO API is limited to a small subset of the methods.
  So these have been well tested. Others have not, and might be
  returning the wrong values anyway!


=head1 IMPLEMENTATION

  The class works by defining a cache where it stores all the results
  from previous method calls.

  The cache is just a single big hash. This is keyed on the method
  names. The value is another hash. This is keyed dependant on the
  function parameters, and the value is the return.

  The way the key is calculated for the second parameter depends on
  what the types of the parameters are. There are four of different
  ways of doing this at the moment.

=head1 FEEDBACK

  Email p.lord@russet.org.uk

=cut



use strict;
use base qw(GO::AppHandle);
use Exporter;

sub new{
  my $class = shift;
  my $self = {};
  bless $self, $class;

  $self->{apph} = shift;
  $self->{apph}->apph( $self );

  ## holds the cache
  $self->{cache} = {};
  return $self;
}

sub disconnect{
  my $self = shift;

  ## clear the cache...
  ## will this work? GO::Model::* objects have a reference
  ## to this object
  $self->{cache} = {};

  ## pass the call on
  $self->{apph}->disconnect;
}

sub _contains{
  my $self = shift;
  my $params = shift;
  my $method = shift;

  return scalar( grep{$_ eq $params} $self->$method() );
}

sub _get_create_cache{
  my $self = shift;
  my $name = shift;

  my $cache = $self->{$name};
  if( defined $cache ){
    return $cache;
  }

  $cache = {};
  $self->{cache}->{$name} = $cache;
  return $cache;
}

## the following methods all contain information about which methods
## take which kind of parameters. Depending on the different types,
## different functions are use to to calculate hashs for the memory cache.
sub _straight_parameter_functions{
  return qw( get_term_by_acc get_terms_by_search );
}

sub _anonymous_hash_functions{
  return qw( get_terms get_term name synonym acc search
  get_relationships get_associations get_all_associations
  get_direct_associations get_product get_products get_deep_products
  get_product_count get_deep_product_count get_paths_to_top );

}

sub _parameter_less_functions{
  return qw( get_root_term get_ontology_root_terms );
}

sub _go_term_functions{
  return qw( get_parent_terms );
}



## Functions I haven't done yet because I don't understand the
## parameters
##
## product_accs, products, get_node_graph, get_graph_by_acc
## get_graph_by_search, get_graph_by_terms

## Functions I haven't done yet because they have stateful
## responses. The point is that the Term objects here are different
## dependant on the parameters given to the function call, which may
## well cause problems when caching.
##
## get_terms_with_associations


## the following define which function calls get their return values
## translated for effiecient in memory representation
sub _term_arrayref_translators{
  ##return qw( get_parent_terms get_terms );
  ##get_terms doesn't really work at the moment. The problem is that
  ##it stores state, in particular get_selected_associations which is
  ##not stored in a simple term array ref.
  return qw( get_parent_terms );
}


## The next set of functions all define different ways of calculating
## the hash which will be used to key the cache. They call take the
## same parameters, calculate a hash

=head2 _anonymous_hash_cache

  This function generates a hash key on which to cache results, for those
  methods which take a single hashref, as a parameter.

=cut

sub _anonymous_hash_cache{
  my $self = shift;
  my $name = shift;
  my $params = shift;

  ## retrieve the parameter which will be an anonymous hash
  my $parameter_hash = @$params->[ 0 ];

  ## turn this hash into a key.
  my $parameter_key =
    ( join '\034', keys( %$parameter_hash ) ) .
      (join '\034', values( %$parameter_hash ) );

  return $parameter_key;
}


=head2 _straight_parameter_cache

  This function uses the parameter itself directly as a key for
  caching results.

=cut

sub _straight_parameter_cache{
  my $self = shift;
  my $name = shift;
  my $params = shift;

  return $params->[ 0 ];
}


=head2 _parameter_less_cache

  This function works where there are no parameters

=cut

sub _parameter_less_cache{
  my $self = shift;
  my $name = shift;
  my $params = shift;

  ## we can use anything we like as a hash key here, so we just use
  ## the function name
  return $name;
}


=head2 _go_terms_cache

  For functions which take a GO::Model::Term object.

=cut

sub _go_term_cache{
  my $self = shift;
  my $name = shift;
  my $params = shift;

  return $params->[ 0 ]->public_acc;
}



## The next set of methods are all "translator" functions. These take
## either a single parameter, in which case the parameter is a
## function return value that needs to be translated into what ever
## should be stored in the cache, or two parameters, in which case the
## first parameter, is a return value from the cache which needs to be
## translated back to real return value.
##
## The point of this tomfoolery is to all an efficient memory
## representation of return values


sub _term_arrayref_translate{
  my $self = shift;
  my $objects = shift;
  my $translate_to_memory = shift;

  my @return_array;

  if( defined $translate_to_memory ){
    foreach my $term( @$objects ){
      push @return_array, $term->public_acc;
    }
  }
  else{
    foreach my $acc( @$objects ){
      push @return_array, $self->get_term_by_acc( $acc );
    }
  }
  return \@return_array;
}


# sub _term_arrayref_with_association_translate{
#   my $self = shift;
#   my $objects = shift;
#   my $translate_to_memory = shift;

#   my @return_array;

#   if( defined $translate_to_memory ){
#     foreach my $term( @$objects ){
#       my @term_with_assoc;
#       push @term_with_assoc, $term->public_acc;
#     }
#   }
# }



## variables holding statistics for debugging
my $called_func = 0;
my $cached_func = 0;


=head2 _cache_function_call

  This function calls a second function in the delegated AppHandle, caching
  the results. Cached results will be returned the second time around.

  Caching is done in a hash, which is keyed on the parameter passed in.

  Args - string representing the method to be called.
         arrayref representing the parameters of the method
         string representing the hash to be used for storing the return

=cut

sub _cache_function_call{
  my $self = shift;
  my $name = shift;
  my $params = shift;
  my $parameter_key = shift;

  ## retrieve the cache.
  my $cache = $self->_get_create_cache( $name );

  ## check the cache to see if it exists.
  my $cached_retn = $cache->{$parameter_key};
  if( defined  $cached_retn ){
    # $cached_func++; print "Cached $cached_func\n";

    ## the call has been done so return the result, translating it
    ## back from its in memory representation
    $cached_retn = $self->_translate( $name, $cached_retn );
    return $cached_retn;
  }

  ## do the function call
  $cached_retn =
    $self->{apph}->$name( @$params );

  # $called_func++;
  ##print "Called $called_func\n";
  ## cache the result, translating it if necessary
  $cache->{$parameter_key}
    = $self->_translate( $name, $cached_retn, 1 );
  return $cached_retn;
}


sub _translate{
  my $self = shift;
  my $name = shift;
  my $objects = shift;
  my $translate_to_memory = shift;

  if( $self->_contains( $name, "_term_arrayref_translators" ) ){
     return $self->_term_arrayref_translate( $objects, $translate_to_memory );
   }

  return $objects;
}


sub AUTOLOAD{
  my $self = shift;

  no strict;
  my $name = $AUTOLOAD;
  use strict;

  $name =~ s/.*://;

  if( $name eq "DESTROY" ){
    return;
  }


  #print "Calling AppHandle $name\n";
  my $parameter_hash;

  if( $self->_contains( $name, "_parameter_less_functions" ) ){
    $parameter_hash = $self->_parameter_less_cache( $name, \@_ );
  }
  elsif( $self->_contains( $name, "_straight_parameter_functions" ) ){
    $parameter_hash = $self->_straight_parameter_cache( $name, \@_ );
  }
  elsif( $self->_contains( $name, "_anonymous_hash_functions" ) ){
    $parameter_hash = $self->_anonymous_hash_cache( $name, \@_ );
  }
  elsif( $self->_contains( $name, "_go_term_functions" ) ){
    $parameter_hash = $self->_go_term_cache( $name, \@_ );
  }
  else{
    ## we don't know how to do anything with this call so pass it on
    return $self->{apph}->$name( @_ );
  }


  ## so if we have got this far then we have the hash that we need,
  ## so we can do the call
  return $self->_cache_function_call( $name, \@_, $parameter_hash );
}


1;
