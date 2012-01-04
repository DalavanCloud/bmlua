module(..., package.seeall)

function Set(other)
  local set = {}
  set.iter = function(self) return pairs(self.contents) end
  set.add = function(self, item) self.contents[item] = true end
  set.discard = function(self, item) self.contents[item] = nil end
  set.length = function(self)
      counter = 0
      for item in self:iter() do
          counter = counter + 1
      end
      return counter
  end
  set.contains = function(self, item) return self.contents[item] == true end
  set.copy = function(self)
      return Set(self)
  end
  set.update = function(self, other)
      for item in other:iter() do self:add(item) end
  end
  set.union = function(self, other)
      result = Set(self)
      result:update(other)
      return result
  end
  set.intersection_update = function(self, other)
      for item in self:iter() do
          if not other:contains(item) then
              self:discard(item)
          end
      end
  end
  set.intersection = function(self, other)
      result = Set(self)
      result:intersection_update(other)
      return result
  end
  set.difference_update = function(self, other)
      for item in other:iter() do self:discard(item) end
  end
  set.difference = function(self, other)
      result = Set(self)
      result:difference_update(other)
      return result
  end
  set.to_array = function(self)
      array = {}
      for item in self:iter() do
          array[#array + 1] = item
          print(item)
      end
      return array
  end
  set.filter_update = function(self, predicate)
      for item in self:iter() do
          if not predicate(item) then self:discard(item) end
      end
  end
  set.filter = function(self, predicate)
      local result = Set(self)
      result:filter_update(predicate)
      return result
  end

  set.contents = {}
  if other ~= nil then
      for item in other:iter() do set:add(item) end
  end
  return set
end

function from_array(array)
    set = Set()
    for idx, item in ipairs(array) do
        set:add(item)
    end
    return set
end

local real_print = print
function print(set)
    for item in set:iter() do
        real_print(item)
    end
end
