--[[

Lua doesn't have type checking, so here's a description of the more
complex types present in this project.

Action function: function(handPos: world vec3) -> none
- Handles user interaction. Commonly used to move vectors around,
  adjust their values, whatever.

Value function: function(self, vecs: table[MBVec], visited: table[vec id]?) -> (val: scene vec3, expression: string)
- Calculates a value for the vector and the associated math expression.

]]
