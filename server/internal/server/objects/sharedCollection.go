package objects

import (
	"maps"
	"sync"
)

// A generic, thread-safe map of objects with auto-incrementing IDs.
type SharedCollection[T any] struct {
	objects map[uint64]T
	nextId  uint64
	mapMux  sync.Mutex
}

func NewSharedCollection[T any](capacity ...int) *SharedCollection[T] {
	var newObjMap map[uint64]T

	if len(capacity) > 0 {
		newObjMap = make(map[uint64]T, capacity[0])
	} else {
		newObjMap = make(map[uint64]T)
	}

	return &SharedCollection[T]{
		objects: newObjMap,
		nextId:  1,
	}
}

// Add a new object to the collection and return its ID
func (c *SharedCollection[T]) Add(obj T, id ...uint64) uint64 {
	c.mapMux.Lock()         // Lock the map so we can safely add the object
	defer c.mapMux.Unlock() // Unlock the map when we're done

	thisId := c.nextId
	if len(id) > 0 {
		thisId = id[0]
	}

	c.objects[thisId] = obj
	c.nextId++
	return thisId
}

// Remove an object from the collection
func (c *SharedCollection[T]) Remove(id uint64) {
	c.mapMux.Lock()         // Lock the map so we can safely remove the object
	defer c.mapMux.Unlock() // Unlock the map when we're done
	delete(c.objects, id)   // Remove the object from the map if it exists
}

// Call the given function for each object in the collection
func (c *SharedCollection[T]) ForEach(f func(uint64, T)) {
	c.mapMux.Lock()                                 // Lock the map so we can safely iterate over the objects
	localCopy := make(map[uint64]T, len(c.objects)) // Make a copy of the map so we can safely iterate over it
	maps.Copy(localCopy, c.objects)                 // Copy the map to the local copy
	defer c.mapMux.Unlock()                         // Unlock the map when we're done

	// Iterate over the local copy without holding the lock.
	for id, obj := range localCopy {
		f(id, obj)
	}
}

// Get the id if it exists otherwise return nil
func (c *SharedCollection[T]) Get(id uint64) (T, bool) {
	c.mapMux.Lock()         // Lock the map so we can safely get the object
	defer c.mapMux.Unlock() // Unlock the map when we're done
	obj, exists := c.objects[id]
	return obj, exists
}

// Get the number of objects in the collection
func (c *SharedCollection[T]) Len() int {
	return len(c.objects)
}
